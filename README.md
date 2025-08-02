[![Actions Status](https://github.com/raku-community-modules/JSON-Path/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Path/actions) [![Actions Status](https://github.com/raku-community-modules/JSON-Path/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Path/actions) [![Actions Status](https://github.com/raku-community-modules/JSON-Path/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Path/actions)

NAME
====

JSON::Path - Implementation of the JSONPath data structure query language

SYNOPSIS
========

```raku
use JSON::Path;

# Example data.
my $data = {
  kitchen => {
    drawers => [
      { knife => '🔪' },
      { glass => '🍷' },
      { knife => '🗡️' },
    ]
  }
};

# A query
my $jp = JSON::Path.new('$.kitchen.drawers[*].knife');

# The first result
dd $jp.value($data);  # "🔪"

# All results.
dd $jp.values($data); # ("🔪", "🗡️").Seq

# All paths where the results were found.
dd $jp.paths($data);  # ("\$.kitchen.drawers[0].knife",
                      #  "\$.kitchen.drawers[2].knife").Seq

# Interleaved paths and values.
dd $jp.paths-and-values($data);
# ("\$.kitchen.drawers[0].knife", "🔪",
#  "\$.kitchen.drawers[2].knife", "🗡️").Seq
```

DESCRIPTION
===========

The [JSONPath query language](https://goessner.net/articles/JsonPath/) was designed for indexing into JSON documents. It plays the same role as XPath does for XML documents.

This module implements `JSON::Path`. However, it is not restricted to working on JSON input. In fact, it will happily work over any data structure made up of arrays and hashes.

Query Syntax Summary
====================

The following syntax is supported:

<table class="pod-table">
<thead><tr>
<th>query</th> <th>description</th>
</tr></thead>
<tbody>
<tr> <td>$</td> <td>root node</td> </tr> <tr> <td>.key</td> <td>index hash key</td> </tr> <tr> <td>[&#39;key&#39;]</td> <td>index hash key</td> </tr> <tr> <td>[2]</td> <td>index array element</td> </tr> <tr> <td>[0,1]</td> <td>index array slice</td> </tr> <tr> <td>[4:5]</td> <td>index array range</td> </tr> <tr> <td>[:5]</td> <td>index from the beginning</td> </tr> <tr> <td>[-3:]</td> <td>index to the end</td> </tr> <tr> <td>.*</td> <td>index all elements</td> </tr> <tr> <td>[*]</td> <td>index all elements</td> </tr> <tr> <td>[?(expr)]</td> <td>filter on (Raku) expression</td> </tr> <tr> <td>..key</td> <td>search all descendants for hash key</td> </tr>
</tbody>
</table>

A query that is not rooted from `$` or specified using `..` will be evaluated from the document root (that is, same as an explicit `$` at the start).

AUTHORS
=======

  * Jonathan Worthington

Source can be located at: https://github.com/raku-community-modules/JSON-Path . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2012 - 2024 Jonathan Worthington

Copyright 2024 - 2025 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

