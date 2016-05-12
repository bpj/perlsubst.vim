# perlsubst.vim

Do a perl substitution over a range, emulating Vim's /c flag.

This is mainly useful if you want to use perl's Unicode features.

# Usage

    :[range]Perlsubst s/{perl-regex}/{perl-qq-string}/[flags]

Instead of / you can use any (perl) non-\w, non-\s character as
delimiter except ( ) < > { } [ ]. The delimiter can and must be
backslash-escaped inside both {perl-regex} and {perl-qq-string}.

WARNING: {perl-qq-string} is repeatedly eval'ed by perl as 

    eval "qq/$string/";

using the same delimiter as you used in the s/// expression.
If that is a concern don't use this script!

Since {perl-qq-string} is eval'ed by perl you can interpolate perl's
regex related global variables like $1, $+, %+, %-, and string modifiers
like \u \l \U \L \Q \E inside it.

Unlike before {perl-regex} is now eval'ed at the same time as it is compiled 
once as

    qr/(?$flags:$regex)/;

again using the same delimiter as in your original s/// expression.
The eval is so that things like \N{CHARNAME} and \x{CODEPOINT} get
evaluated correctly. Again if the perl eval is a concern don't use this script!

All [flags] which are valid in such a qr// expression 
for the version of perl which Vim was compiled with are supported.
Additionally /g is fudged to work as you would expect.

Confirmation: by default you are asked to confirm each substitution.
A message is shown for each match:

    Replace "{match-context}" with "{replacement}" on line {lnum}? (y/n/a/l/q)

which in practice is something like
    
    Replace "ike using -->p<--erl in vim" with "P" on line 9? (y/n/a/l/q) 

Here the text between -->...<-- is the current match text, and what comes
before and after inside the first double quotes is up to ten characters of
context. If you think 10 characters of context before and after is too
much/little you can set the context length to something else with

    :perldo $main::Perlsubst_context = {integer}

where {integer} of course should be replaced with your desired context length.

You are now supposed to type one of the characters y/n/a/l/q AND HIT
RETURN, since it is necessary to use input() here! They are made to behave 
as much as described under [c] at :help :s_flags as I could make them.
In fact n is the default: any input other than y/a/l/q/ results in the
current match not being replaced and the next match being found.

Currently you have to use perl version 5.10 or higher. Things will
probably work also on 5.8 if you remove the line with "use 5.010;" and 
change "${^PREMATCH}", "${^MATCH}" and "${^POSTMATCH}" into
"$`", "$&" and "$'" respectively. Versions of perl prior to 5.18 will
perform worse, though not in terms of accuracy, then,
but you probably knew that already.

Note that it is necessary to use the Encode module to decode/encode
text going from/to vim. Otherwise lines already containing multibyte
characters will be mangled. The default encoding is &encoding 
(Note that 'utf-8' gives what Encode calls 'utf-8-strict' and
not perl's laxer 'utf8' variant). If you get the wrong encoding
(i.e. the Encode module doesn't know your encoding under the name which
Vim uses) find out the name Encode uses and set the function to use that 
encoding with

    :perldo $main::Perlsubst_encoding = {encoding-name}
    :perldo $main::Perlsubst_encoder = undef

The latter because the Encode object is cached. It is not populated until
you use the Perlsubst command the first time.

# Author

Benct Philip Jonsson <bpjonsson@gmail.com>

