---
last-change: 2016 May 25
...

<!--
NOTE TO CONTRIBUTORS

Please note that any text in README.md with Markdown `**strong-emphasis**` will become a vimdoc `*tag-target*` and any text with Markdown `*ordinary-emphasis*` will become a vimdoc `|hot-link|`!
-->

# perlsubst.vim **perlsubst**

Do a perl substitution over a range, emulating Vim's `/c` flag.

This is useful if you want to do a substitution using Perl regular expressions, and be able to interactively confirm each substitution.

Substituting with perl offers a number of features not found in native Vim:

*   A [regex engine][] which can do some things Vim's can't (and can't do some things Vim's can).
*   You can search for characters having specific [Unicode properties][] using the `\p{PROPERTY}` syntax.
*   You can search/replace characters by their [Unicode names][], using the `\N{CHARNAME}` syntax.
*   You can search/replace combining characters independently of their base characters.
*   You can use named captures and recurse into them too.

If you don't need the interactive confirmation _:perldo_ will do the same things much faster.

[regex engine]:         <http://perldoc.perl.org/perlre.html>
[Unicode properties]:   <http://perldoc.perl.org/perluniprops.html>
[Unicode names]:        <http://perldoc.perl.org/charnames.html>

# USAGE		**perlsubst-usage** **:Perlsubst**

````
:[range]Perlsubst s/{perl-regex}/{replacement}/[flags]
````

The default range is the current line, just as with Vim's *:s*.

Instead of `/` you can use any (perl) non-`\w`, non-`\s` character as delimiter except `( ) < > { } [ ]`. The delimiter can and must be backslash-escaped inside both {perl-regex} and {replacement}.

## WARNING		**perlsubst-warning** **perlsubst-perl-eval** 

The {replacement} is repeatedly eval'ed by perl as 

````
eval "qq/$replacement/";
````

using the same delimiter as you used in the `s///` expression. If that is a concern don't use this script!

Unlike the initial version of this script {perl-regex} is now eval'ed at the same time as it is compiled once as

````
eval "qr/(?$flags:$regex)/";
````

again using the same delimiter as in your original `s///` expression. The eval is so that things like `\N{CHARNAME}` and `\x{CODEPOINT}` get resolved correctly. Again if the perl eval is a concern don't use this script!

### DOUBLE WARNING - PERL CODE AS REPLACEMENT		**perlsubst-double-warning** **perlsubst-replacement-code**

As of version 0.007 the script understands the (perl) `/e` flag to the substitution expression. If the perl global variable `$main::Perlsubst_allow_replacement_eval` has been set to a true value and there is an `/e` flag, the {replacement} will be eval'ed as Perl code rather than as a quoted string. This feature can really wreak havoc, so don't use it unless you fully understand what it means! I added it because I needed to make a replacement conditional on whether some capture group had matched, which isn't possible otherwise.

## INTERPOLATION		**perlsubst-interpolation** 

Since {replacement} is eval'ed by perl you can interpolate perl's regex related global variables like `$1 $+ %+ %-`, named and numeric character references like `\N{CHARNAME}` and `\x{CODEPOINT}`,  and string modifiers like `\u \l \U \L \Q \E` inside it. The same is true of {perl-regex} although interpolating regex variables inside it isn't guaranteed to work.

## FLAGS		**perlsubst-flags** 

All `[flags]` which are valid in a `qr//` expression for the version of perl which Vim was built with are supported. Additionally `/g` is fudged to work as you would expect.

## CONFIRMATION		**perlsubst-confirmation** 

By default you are asked to confirm each substitution. A message is shown for each match:

````
Replace "{match-context}" with "{replacement}" on line {lnum}? (y/n/a/l/q)
````

which in practice is something like
	
````
Replace "ike using -->p<--erl in vim" with "P" on line 9? (y/n/a/l/q) 
````

Here the text between `-->...<--` is the current match text, and what comes before and after inside the first double quotes is up to ten characters of context. If you think 10 characters of context before and after is too much/little you can set the context length to something else with

````
:perldo $main::Perlsubst_context = {integer}
````

where {integer} of course should be replaced with your desired context length.

You are now supposed to type one of the characters y/n/a/l/q AND HIT RETURN, since it is necessary to use _input()_ here! They are made to behave as much as described under `[c]` at _:s_flags_ as I could make them. In fact n is the default: any input other than y/a/l/q/ results in the current match not being replaced and the next match being found.


# REQUIRED PERL VERSION		**perlsubst-required-perl-version** 

You have to use a Vim built with perl interface, and currently the builtin perl must be version 5.10 or higher. Things will probably work also with perl 5.8 if you remove the line with `use 5.010;` and change `` ${^PREMATCH} ``, `` ${^MATCH} `` and `` ${^POSTMATCH} `` into `` $` ``, `$&` and `` $' `` respectively. Versions of perl prior to 5.18 will perform worse, though not in terms of accuracy, then, but you probably knew that already.

# ENCODING		**perlsubst-encoding** 

Note that it is necessary to use the Encode module to decode/encode text going from/to vim. Otherwise lines containing multibyte characters will be mangled. The default encoding is whatever Vim's 'encoding' is. (Note that 'utf-8' gives what Encode calls 'utf-8-strict' and not perl's laxer 'utf8' variant). If you get the wrong encoding (i.e. the Encode module doesn't know your encoding under the name which Vim uses) find out the name Encode uses at <https://metacpan.org/pod/Encode::Supported> and set the function to use that encoding with

````
:perldo $main::Perlsubst_encoding = {encoding-name}
:perldo $main::Perlsubst_encoder = undef
````

The latter because the Encode object is cached. It is not populated until you use the Perlsubst command the first time.

# AUTHOR		**perlsubst-author** 

Benct Philip Jonsson <bpjonsson@gmail.com>

# REPOSITORY		**perlsubst-repository** 

<https://github.com/bpj/perlsubst.vim/>

## ISSUES/BUGS		**perlsubst-issues** **perlsubst-bugs** 

Please report bugs to:

<https://github.com/bpj/perlsubst.vim/issues>

* * * *

<!-- vim: set sw=8 ts=8 sts=8 noet list: -->
