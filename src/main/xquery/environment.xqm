xquery version "3.1";

(:~
 : This module defines functions and data structures for evaluating
 : XPath expressions within a user-supplied environment.
 :)

module namespace env = "tag:dmaus@dmaus.name,2020:Schematron:Environment";

declare function env:create-environment () as map(*)+ {
  env:create-environment((), ())
};

declare function env:create-environment ($contextNode as node()*) as map(*)+ {
  env:create-environment($contextNode, ())
};

declare function env:create-environment ($contextNode as node()*, $enclosing as map(*)*) as map(*)+ {
  (map{"context": $contextNode, "variables": map{}, "namespaces": map{}}, $enclosing)
};

declare function env:get-context ($env as map(*)+) as node()* {
  map:get(head($env), "context")
};

declare function env:get-namespaces ($env as map(*)+) as map(xs:string, xs:anyURI) {
  map:get(head($env), "namespaces")
};

declare function env:set-namespaces ($env as map(*)+, $namespaces as map(xs:string, xs:anyURI)) as map(*)+ {
  (
  map:put(head($env), "namespaces", $namespaces),
  tail($env)
  )
};

declare function env:get-variables ($env as map(*)+) as map(xs:QName, item()*) {
  map:get(head($env), "variables")
};

declare function env:set-variables ($env as map(*)+, $variables as map(xs:QName, item()*)) as map(*)+ {
  (
  map:put(head($env), "variables", $variables),
  tail($env)
  )
};

declare function env:declare-namespace ($env as map(*)+, $prefix as xs:string, $uri as xs:anyURI) as map(*)+ {
  env:set-namespaces($env, map:put(env:get-namespaces($env), $prefix, $uri))
};

declare function env:declare-variable ($env as map(*)+, $name as xs:QName, $valueExpr as item()*) as map(*)+ {
  let $value as item()* := if ($valueExpr instance of node()*) then $valueExpr else env:evaluate($env, $valueExpr)
  return
    env:set-variables($env, map:put(env:get-variables($env), $name, $value))
};

declare function env:get-namespace-uri ($env as map(*)+, $prefix as xs:string) as xs:anyURI? {
  let $namespaces := map:merge($env ! env:get-namespaces(.), map{"duplicates": "use-first"})
  return
    if (map:contains($namespaces, $prefix))
      then map:get($namespaces, $prefix)
      else
      if ($prefix eq '')
        then ()
        else error()
};

declare function env:evaluate ($env as map(*)+, $expr as xs:string) as item()* {
  let $bindings as map(*) := map:merge(for-each($env, env:get-variables(?)))
  let $bindings as map(*) := map:put($bindings, "", env:get-context($env))
  let $prolog as xs:string := env:create-prolog($env)
   return
    xquery:eval(concat($prolog, $expr), $bindings)
};

declare %private function env:create-prolog ($env as map(*)+) as xs:string {
  let $varDecl as xs:string* := env:create-prolog-variables($env)
  let $nsDecl as xs:string* := env:create-prolog-namespaces($env)
  return
    string-join(($nsDecl, $varDecl))
};

declare %private function env:create-prolog-namespaces ($env as map(*)+) as xs:string* {
  let $namespaces := map:merge($env ! env:get-namespaces(.), map{"duplicates": "use-first"})
  return
    for-each(map:keys($namespaces), function ($prefix as xs:string) {
      concat("declare namespace ", $prefix, " = '", map:get($namespaces, $prefix), "';")
    })
};

declare %private function env:create-prolog-variables ($env as map(*)+) as xs:string* {
  let $variables := map:merge($env ! env:get-variables(.), map{"duplicates": "use-first"})
  return
    for-each(map:keys($variables), function ($name as xs:QName) {
      concat("declare variable $", string($name), " external;")
    })
};