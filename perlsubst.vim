" Name: perlsubst.vim
" Description: Do a perl substitution over a range, emulating Vim's /c flag.
"   This is mainly useful if you want to use perl's Unicode features.
" Version: 0.002 2016-05-12
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
"       :perldo $main::Perlsubst_context = {integer}
"
"   where {integer} of course should be replaced with your desired context length.
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
"   characters will be mangled. The default encoding is &encoding 
"   (Note that 'utf-8' gives what Encode calls 'utf-8-strict' and
"   not perl's laxer 'utf8' variant). If you get the wrong encoding
"   (i.e. the Encode module doesn't know your encoding under the name which
"   Vim uses) find out the name Encode uses and set the function to use that 
"   encoding with
"
"       :perldo $main::Perlsubst_encoding = {encoding-name}
"       :perldo $main::Perlsubst_encoder = undef
"
"   The latter because the Encode object is cached. It is not populated until
"   you use the Perlsubst command the first time.

fun! s:perl_subst(line1, line2, expr)
    perl <<
    use 5.010;
    use utf8;
    use Encode qw[ find_encoding ];
    my $line1 = VIM::Eval( 'a:line1' );
    my $line2 = VIM::Eval( 'a:line2' );
    my $expr  = VIM::Eval( 'a:expr' );
    $Perlsubst_encoder ||= find_encoding(
        $Perlsubst_encoding || Vim::Eval('&encoding') );
    $expr = $Perlsubst_encoder->decode( $expr );
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
            $line = $Perlsubst_encoder->decode( $line );
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
                    my $msg
                      = qq{Replace "$show_match" with "$replacement" on line $l? (y/n/a/l/q) };
                    $msg =~ s/'/''/g;
                    my $res = VIM::Eval( $Perlsubst_encoder->encode( qq{input('$msg')} ) );
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
            $line = $Perlsubst_encoder->encode( $line );
            $curbuf->Set( $l, $line );
            last RANGE if $last;
        }
    }
    else {
        VIM::Msg( $Perlsubst_encoder->encode("Invalid Persubst expression: $expr"), 'ErrorMsg' );
    }
.
endfun

com! -range -nargs=1 Perlsubst call s:perl_subst(<line1>, <line2>, <f-args>)
