" Name: perlsubst.vim
" Description: Do a perl substitution over a range, emulating Vim's /c flag.
"   This is mainly useful if you want to use perl's Unicode features.
" Version: 0.007 2016-05-17
" Author: Benct Philip Jonsson <bpjonsson@gmail.com>
" License: MIT Licence
"
" Usage: See https://github.com/bpj/perlsubst.vim
"
" Changes:
"
"   Date:   Wed May 25 14:00:53 2016 +0200
"       allow empty string as regex/replacement; fixes #1
"   Date:   Tue May 17 16:20:02 2016 +0200
"       added code-as-replacement feature
"   Date:   Thu May 12 16:21:56 2016 +0200
"       eval the search pattern so that charnames work
"   Date:   Thu May 12 16:03:26 2016 +0200
"       use charnames
"   Date:   Thu May 12 14:03:29 2016 +0200
"       made encoding dynamic, now uses 'encoding'
"   Date:   Wed May 25 14:24:19 2016 +0200
"       backslash escape handling in extraction pattern was broken 
"       (what was I thinking of!)

if exists('g:loaded_perlsubst')
  finish
endif
if !has('perl')
    finish
endif
let g:loaded_perlsubst = 1


let s:save_cpo = &cpo
set cpo&vim

fun! s:perl_subst(line1, line2, expr)
    perl <<
    use 5.010;
    use utf8;
    use Encode qw[ find_encoding ];
    use charnames qw[ :full :short ];
    my $line1 = VIM::Eval( 'a:line1' );
    my $line2 = VIM::Eval( 'a:line2' );
    my $expr  = VIM::Eval( 'a:expr' );
    $Perlsubst_encoder ||= find_encoding(
        $Perlsubst_encoding || VIM::Eval('&encoding') );
    $expr = $Perlsubst_encoder->decode( $expr );
    my @range     = $curbuf->Get( $line1 .. $line2 );
    my $range_end = $#range;
    if ( $expr =~ s/^s(?=([^\[\]\{\}\(\)\<\>\s\w]))// ) {
        my $del = $1;
        my ( $search, $replace, $mods )
          = $expr =~ /(?>\Q$del\E((?:[^\Q$del\E\\]|\\.)*))/g;
        my $global = $mods =~ s/g//;
        my $eval = $mods =~ s/e// && $Perlsubst_allow_replacement_eval;
        $search = eval "qr$del(?$mods:$search)$del";
        $replace = "qq$del$replace$del" unless $eval;
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

if !exists(':Perlsubst')
    com -range -nargs=1 Perlsubst call s:perl_subst(<line1>, <line2>, <f-args>)
endif


let &cpo = s:save_cpo
unlet s:save_cpo

