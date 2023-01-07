# Schematron XQuery

Experiments with a pure XQuery implementation of ISO Schematron.

Copyright (c) 2020-23 by David Maus <dmaus@dmaus.name>.

## Example

```xquery
xquery version "3.1";

import module namespace schematron = "tag:dmaus@dmaus.name,2020:Schematron" at "main/xquery/schematron.xqm";

declare namespace sch = "http://purl.oclc.org/dsdl/schematron";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";

let $document as node() := document{<root><element/></root>}
let $schema as element(sch:schema) :=
<sch:schema>
<sch:let name="foo" value="'bar'"/>
<sch:pattern>
<sch:rule context="*">
<sch:assert test="true()"/>
<sch:assert id="a" test="false()"/>
<sch:report test="local-name() eq 'element'"/>
<sch:report test="$foo eq 'bar'"/>
</sch:rule>
</sch:pattern>
</sch:schema>

return
  schematron:validate($document, $schema)
```
