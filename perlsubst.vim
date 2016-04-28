" Name: perlsubst.vim
" Description: Do a perl substitution over a range, emulating Vim's /c flag.
"   This is mainly useful if you want to use perl's Unicode features.
" Version: 0.001 2016-04-28
" Author: Benct Philip Jonsson <bpjonsson@gmail.com>
" License: Same license as Vim
"
" Usage:
"   :[range]Perlsubst s/{perl-regex}/{perl-qq-string}/[flags]
"
"   Instead of / you can use any (perl) non-\w, non-\s character as
"   delimiter except ( ) < > { } [ ]. The delimiter can and must be
"   backslash-escaped inside both {perl-regex} and {perl-qq-string}.
"
"   WARNING: {perl-qq-string} is repeatedly eval'ed by perl as 
"
"       eval "qq/$string/";
"
"   using the same delimiter as you used in the s/// expression.
"   If that is concern don't use this script!
"
"   Since {perl-qq-string} is eval'ed by perl you can interpolate perl's
"   regex related global variables like $1, $+, %+, %-, and string modifiers
"   like \u \l \U \L \Q \E inside it.
"
"   OTOH {perl-regex} is not eval'ed. It is compiled once as
"
"       qr/(?$flags:$regex)/;
"
"   Thus all [flags] which are valid in such an expression 
"   for the version of perl which vim was compiled with are supported.
"   Additionally /g is fudged to work as you would expect.
"
"   Confirmation: by default you are asked to confirm each substitution.
"   A message is shown for each match:
"
"       Replace "{match-context}" with "{replacement}" on line {lnum}? (y/n/a/l/q)
"
"   which in practice is something like
"       
"       Replace "ike using -->p<--erl in vim" with "P" on line 9? (y/n/a/l/q) 
"
"   Here the text between -->...<-- is the current match text, and what comes
"   before and after inside the first double quotes is up to ten characters of
"   context. If you think 10 characters of context before and after is too
"   much/little you can set the context length to something else with
"
"       :perldo $main::Perlsubst_context = 15
"
"   where 15 of course should be replaced with your desired context length.
"
"   You are now supposed to type one of the characters y/n/a/l/q AND HIT
"   RETURN, since it is necessary to use input() here! They are made to behave 
"   as much as described under [c] at :help :s_flags as I could make them.
"   In fact n is the default: any input other than y/a/l/q/ results in the
"   current match not being replaced and the next match being found.
"
"   Currently you have to use perl version 5.10 or higher. Things will
"   probably work also on 5.8 if you remove the line with "use 5.010;" and 
"   change "${^PREMATCH}", "${^MATCH}" and "${^POSTMATCH}" into
"   "$`", "$&" and "$'" respectively. Versions of perl prior to 5.18 will
"   perform worse, though not in terms of accuracy, then,
"   but you probably knew that already.
"
"   Note that it is necessary to use the Encode module to decode/encode
"   text going from/to vim. Otherwise lines already containing multibyte
"   characters will be mangled.

fun! s:perl_subst(line1, line2, expr)
    perl <<
    use 5.010;
    use utf8;
    use Encode qw[ decode_utf8 encode_utf8 ];
    my $line1 = VIM::Eval( 'a:line1' );
    my $line2 = VIM::Eval( 'a:line2' );
    my $expr  = VIM::Eval( 'a:expr' );
    $expr = decode_utf8( $expr );
    my @range     = $curbuf->Get( $line1 .. $line2 );
    my $range_end = $#range;
    if ( $expr =~ s/^s([^\[\]\{\}\(\)\<\>\s\w])// ) {
        my $del = $1;
        my ( $search, $replace, $mods )
          = $expr =~ /((?>(?:[^\Q$del\E]|\\\Q$del\E)+))/g;
        my $global = $mods =~ s/g//;
        $search = qr/(?$mods:$search)/;
        $replace = "qq$del$replace$del";
        my $ctx = $Perlsubst_context;
        $ctx = 10 unless defined $ctx;
        my ( $changed, $all, $quit, $last );
      RANGE:
        for my $i ( 0 .. $range_end ) {
            my $l    = $line1 + $i;
            my $line = $range[$i];

            # my $utf8 = is_utf8($line);
            $line = decode_utf8( $line );

            # my $oldpos = pos($line) = 0;
            # last RANGE;
            my $count = 0;
            my $changed = $line =~ s%$search%
                my $replacement = eval $replace;
                my $match       = ${^MATCH};
                my $prematch    = ${^PREMATCH};
                my $postmatch   = ${^POSTMATCH};
                if ( $count++ && !$global or $quit || $last ) {
                    $match;
                }
                elsif ( $all ) {
                    $replacement;
                }
                else {
                    # $curwin->Cursor($l, $c[0]+1);
                    my ( $pre )    = $prematch =~ /(\X{0,$ctx})$/;
                    my ( $post )   = $postmatch =~ /^(\X{0,$ctx})/;
                    my $show_match = "$pre-->$match<--$post";
                    our $msg
                      = qq{Replace "$show_match" with "$replacement" on line $l? (y/n/a/l/q) };
                    $msg =~ s/'/''/g;
                    my $res = VIM::Eval( encode_utf8( qq{input('$msg')} ) );
                    if ( 'a' eq $res ) {
                        $all = 1;
                        $replacement;
                    }
                    elsif ( 'l' eq $res ) {
                        $last = 1;
                        $replacement;
                    }
                    elsif ( 'q' eq $res ) {
                        $quit = 1;
                        $match;
                    }
                    elsif ( 'y' eq $res ) {
                        $replacement;
                    }
                    else {
                        $match;
                    }
                }
            %egp;
            last RANGE if $quit;
            next RANGE unless $changed;
            $line = encode_utf8( $line );
            $curbuf->Set( $l, $line );
        }
    }
    else {
        VIM::Msg( encode_utf8("Invalid Persubst expression: $expr"), 'ErrorMsg' );
    }
.
endfun

com! -range -nargs=1 Perlsubst call s:perl_subst(<line1>, <line2>, <f-args>)
