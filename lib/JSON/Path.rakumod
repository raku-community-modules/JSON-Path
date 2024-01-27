use JSON::Fast;

class JSON::Path {
    has $!path;
    has &!collector;
    has Bool $.allow-eval = False;;

    my enum ResultType < ValueResult PathResult PathAndValueResult MapResult >;

    grammar Parser {
        token TOP {
            <commandtree>
        }

        token commandtree {
            [ <command> || <.giveup> ]
            [ $ || <commandtree> ]
        }

        proto token command    { * }
        token command:sym<$>   { <sym> }
        token command:sym<.>   { <sym>? <ident> }
        token command:sym<[*]> { <sym> | '.*' | [^ || <?after '.'>] '*' }
        token command:sym<..>  { <sym> }
        token command:sym<[n]> {
            | '[' ~ ']' $<n>=[\d+]
        }
        token command:sym<['']> {
            "['" ~ "']" $<key>=[<-[']>+]
        }
        token command:sym<[n1,n2]> {
            '[' ~ ']' [ [ $<ns>=[\d+] ]+ % ',' ]
        }
        token command:sym<[n1:n2]> {
            '[' ~ ']' [ $<n1>=['-'?\d+] ':' [$<n2>=['-'?\d+]]? ]
        }
        token command:sym<[?()]> {
            '[?(' ~ ')]' <code>
        }

        token code {
            [
            | <-[()]>
            | '(' <.code>? ')'
            ]+
        }

        method giveup() {
            die "JSON path parse error at position " ~ self.pos;
        }
    }

    my class BuildClosureTree {
        has Bool $.allow-eval is required;

        method TOP($/) {
            my $evaluator = $<commandtree>.ast;
            make -> $current, $path, $result-type {
                my $*JSON-PATH-ROOT = $current;
                $evaluator($current, $path, $result-type);
            }
        }

        method commandtree($/) {
            my $command = $<command>.ast;
            my $next = $<commandtree>
                    ?? $<commandtree>.ast
                    !! -> \result, @path, $result-type {
                        given $result-type {
                            when ValueResult { take result.item }
                            when PathResult  { take @path.join('') }
                            when PathAndValueResult {
                                take @path.join('');
                                take result.item;
                            }
                            when MapResult   { take result = &*JSON-PATH-MAP(result) }
                        }
                    }
            make -> $current, @path, $result-type {
                $command($next, $current, @path, $result-type);
            }
        }

        method command:sym<$>($/) {
            make sub ($next, $current, @path, $result-type) {
                $next($*JSON-PATH-ROOT, ['$'], $result-type);
            }
        }

        method command:sym<.>($/) {
            my $key = ~$<ident>;
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Associative and $current{$key}:exists {
                    $next($current{$key}, [flat @path, self!enc-key($key)], $result-type);
                }
            }
        }

        method command:sym<[*]>($/) {
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Positional {
                    for $current.kv -> $idx, $object {
                        $next($object, [flat @path, "[$idx]"], $result-type);
                    }
                }
                elsif $current ~~ Associative {
                    for $current.kv -> $key, $object {
                        $next($object, [flat @path, self!enc-key($key)], $result-type);
                    }
                }
            }
        }

        method command:sym<..>($/) {
            make sub ($next, $current, @path, $result-type) {
                multi descend(Associative $o, @path) {
                    for $o.kv -> $key, $value {
                        my @next-path = flat @path, self!enc-key($key);
                        $next($value, @next-path, $result-type);
                        descend($value, @next-path);
                    }
                }

                multi descend(Positional $o, @path) {
                    for $o.list.kv -> $idx, $value {
                        my @next-path = flat @path, "[$idx]";
                        $next($value, @next-path, $result-type);
                        descend($value, @next-path);
                    }
                }

                multi descend(Any $o, @path) {
                    # Terminal, so can't index further into it
                }

                descend($current, @path);
            }
        }

        method command:sym<[n]>($/) {
            my $idx = +$<n>;
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Positional and $current[$idx]:exists {
                    $next($current[$idx], [flat @path, "[$idx]"], $result-type);
                }
            }
        }

        method command:sym<['']>($/) {
            my $key = ~$<key>;
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Associative and $current{$key}:exists {
                    $next($current{$key}, [flat @path, self!enc-key($key)], $result-type);
                }
            }
        }

        method command:sym<[n1,n2]>($/) {
            my @idxs = $<ns>>>.Int;
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Positional {
                    for @idxs {
                        if $current[$_]:exists {
                            $next($current[$_], [flat @path, "[$_]"], $result-type);
                        }
                    }
                }
            }
        }

        method command:sym<[n1:n2]>($/) {
            my ($from, $to) = (+$<n1>, $<n2> ?? +$<n2> !! Inf);
            make sub ($next, $current, @path, $result-type) {
                if $current ~~ Positional {
                    my @idxs =
                            (($from < 0 ?? +$current + $from !! $from) max 0)
                            ..
                            (($to < 0 ?? +$current + $to !! $to) min ($current.?end // 0));
                    for @idxs {
                        $next($current[$_], [flat @path, "[$_]"], $result-type);
                    }
                }
            }
        }

        method command:sym<[?()]>($/) {
            die "Evaluation of embedded Raku code not allowed (construct with :allow-eval)"
                unless $!allow-eval;

            use MONKEY-SEE-NO-EVAL;
            my &condition = EVAL '-> $_ { my $/; ' ~ ~$<code> ~ ' }';
            no MONKEY-SEE-NO-EVAL;
            make sub ($next, $current, @path, $result-type) {
                for @($current).grep(&condition) {
                    $next($_, @path, $result-type);
                }
            }
        }

        method !enc-key($key) {
            $key ~~ /^<.ident>$/ ?? ".$key" !! "['$key']";
        }
    }

    multi method new($path, *%options) {
        self.bless(:$path, |%options);
    }

    submethod TWEAK(Str() :$!path) {
        my $actions = BuildClosureTree.new(:$!allow-eval);
        &!collector = Parser.parse($!path, :$actions).ast;
    }

    multi method Str(JSON::Path:D:) {
        $!path
    }

    method !get($object, ResultType $result-type) {
        my $target = $object ~~ Str
                ?? from-json($object)
                !! $object;
        gather &!collector($target, ['$'], $result-type);
    }

    method paths($object) {
        self!get($object, PathResult)
    }

    method values($object) {
        self!get($object, ValueResult)
    }

    method paths-and-values($object) {
        self!get($object, PathAndValueResult)
    }

    method value($object) is rw {
        self.values($object).head
    }

    method map($object, &*JSON-PATH-MAP) {
        self!get($object, MapResult).eager
    }

    method set(Pair (:key($object), :value($substitute)), $limit = Inf) {
        my $sub'd = 0;
        self.map($object, -> $orig {
            if $sub'd < $limit {
                $sub'd++;
                $substitute
            }
            else {
                $orig
            }
        });
        $sub'd
    }
}

sub jpath($object, $expression) is export {
	JSON::Path.new($expression).values($object);
}

sub jpath1($object, $expression) is rw is export {
	JSON::Path.new($expression).value($object);
}

sub jpath_map(&coderef, $object, $expression) is export {
	JSON::Path.new($expression).map($object, &coderef);
}

=begin pod

=head1 NAME

JSON::Path - Implementation of the JSONPath data structure query language

=head1 SYNOPSIS

=begin code :lang<raku>

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

=end code

=head1 DESCRIPTION

The L<JSONPath query language|https://goessner.net/articles/JsonPath/>
was designed for indexing into JSON documents. It plays the same role
as XPath does for XML documents.

This module implements C<JSON::Path>. However, it is not restricted to
working on JSON input. In fact, it will happily work over any data
structure made up of arrays and hashes.

=head1 Query Syntax Summary

The following syntax is supported:

=begin code

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

=end code

A query that is not rooted from C<$> or specified using C<..> will be
evaluated from the document root (that is, same as an explicit C<$> at
the start).

=head1 AUTHOR

Jonathan Worthington

=head1 COPYRIGHT AND LICENSE

Copyright 2012 - 2024 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
