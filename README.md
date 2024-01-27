[![Actions Status](https://github.com/lizmat/JSON-Path/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/JSON-Path/actions)

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

    $           root node
    .key        index hash key
    ['key']     index hash key
    [2]         index array element
    [0,1]       index array slice
    [4:5]       index array range
    [:5]        index from the beginning
    [-3:]       index to the end
    .*          index all elements
    [*]         index all elements
    [?(expr)]   filter on (Raku) expression
    ..key       search all descendants for hash key

A query that is not rooted from `$` or specified using `..` will be evaluated from the document root (that is, same as an explicit `$` at the start).

AUTHOR
======

Jonathan Worthington

COPYRIGHT AND LICENSE
=====================

Copyright 2012 - 2024 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

