xquery version "3.1";

(:~
 :
 : Schematron implementation.
 :
 :)

module namespace schematron = 'tag:dmaus@dmaus.name,2020:Schematron';

import module namespace env = "tag:dmaus@dmaus.name,2020:Schematron:Environment" at "environment.xqm";

declare namespace sch = "http://purl.oclc.org/dsdl/schematron";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";

declare function schematron:validate ($node as node(), $schema as element(sch:schema)) as element()* {
  let $env := schematron:create-environment($node, $schema/sch:let, $schema/sch:ns, ())
  return
  (
    schematron:check-patterns($env, $schema/sch:pattern),
    for $child in $node/node()
      return schematron:validate($child, $schema)
  )
};

declare function schematron:check-patterns ($env as map(*), $patterns as element(sch:pattern)*) as element()* {
  for-each($patterns, function ($pattern as element(sch:pattern)) as element()* {
    schematron:check-pattern($env, $pattern)
  })
};

declare function schematron:check-pattern ($env as map(*), $pattern as element(sch:pattern)) as element()* {
  let $env := schematron:create-environment(env:get-context($env), $pattern/sch:let, (), $env)
  return
    for-each($pattern/sch:rule, function ($rule as element(sch:rule)) as element()* {
      schematron:check-rule($env, $rule, env:evaluate($env, $rule/@context))
    })
};

declare function schematron:check-rule ($env as map(*)+, $rule as element(sch:rule), $nodes as node()*) as element()* {
  for-each($nodes, function ($node as node()) as element()* {
    let $env as map(*)+ := schematron:create-environment($node, $rule/sch:let, (), $env)
    return
    (
      $rule/sch:assert ! schematron:check-assert($env, .),
      $rule/sch:report ! schematron:check-report($env, .)
    )
  })
};

declare function schematron:check-assert ($env as map(*)+, $assert as element(sch:assert)) as element(svrl:failed-assert)? {
  if (boolean(env:evaluate($env, string($assert/@test))))
    then ()
    else
      <svrl:failed-assert location="{env:evaluate($env, 'path()')}">{$assert/@*}</svrl:failed-assert>
};

declare function schematron:check-report ($env as map(*)+, $report as element(sch:report)) as element(svrl:successful-report)? {
  if (boolean(env:evaluate($env, string($report/@test))))
    then <svrl:successful-report location="{env:evaluate($env, 'path()')}">{$report/@*}</svrl:successful-report>
    else
      ()
};

declare function schematron:create-environment ($contextNode as node()*, $variables as element(sch:let)*, $nsDecls as element(sch:ns)*, $enclosing as map(*)*) as map(*)+ {
  let $environment as map(*)+ := env:create-environment($contextNode, $enclosing)
  let $environment as map(*)+ := fold-left($nsDecls, $environment, function ($env as map(*)+, $decl as element(sch:ns)) as map(*)+ {
    env:declare-namespace($env, string($decl/@prefix), xs:anyURI($decl/@uri))
  })
  return
    fold-left($variables, $environment, function ($env as map(*)+, $decl as element(sch:let)) as map(*)+ {
      env:declare-variable($env, schematron:qualify-name($env, string($decl/@name)), if ($decl/@value) then string($decl/@value) else $decl/node())
    })
};

declare %private function schematron:qualify-name ($env as map(*)+, $name as xs:string) as xs:QName {
  QName(env:get-namespace-uri($env, substring-before($name, ":")), $name)
};

declare %private function schematron:create-namespace-map ($namespaces as element(sch:ns)*) as map(xs:string, xs:anyURI) {
  fold-left($namespaces, map{}, function ($map as map(xs:string, xs:anyURI), $decl as element(sch:ns)) as map(xs:string, xs:anyURI) {
    map:put($map, string($decl/@prefix), xs:anyURI($decl/@uri))
  })
};