package SafeMatchStats;

use v5.14;
use utf8;

use Try::Tiny;
use Safe;
use Carp;

use Exporter;

our @ISA    = qw( Exporter );
our @EXPORT = qw( match_gather );

our $VERSION = 0.01;

sub match_gather {
    my( $target, $regexp, $modifiers ) = @_;
    my $re_obj = _safe_qr( $regexp, $modifiers );
    my $match;
    try { 
        $match = _safe_match_gather( $target, $re_obj );
    } catch {
        $match = undef;
    };
    return $match;  # Hashref for success.  0 for failure.  undef for error.
}

sub _safe_qr {
    my( $regexp, $modifiers ) = @_;
    $regexp = _sanitize_re_string( $regexp );
    if( defined $modifiers ) {
        $modifiers =~ tr/msixadlu^-//cd;
        $regexp = "(?$modifiers:$regexp)";
    }
    my $compartment = Safe->new;
    ${$compartment->varglob('regexp')} = $regexp;
    my $re_obj = $compartment->reval( <<'REVAL' );
        local ( 
        );
        my $safe_reg = qr/$regexp/;
        $safe_reg;
REVAL
    return $re_obj;
}

sub _sanitize_re_string {
    my $re_string = shift;
    no warnings 'qw';
    my @possible_varnames = qw%
        \$\w            \$\^\w      \@\w        \$#\w   
        \$[()<>#!+-]    \$.[\[\{]   \$\{\w+}    \@\{\w+}
    %;
    foreach my $bad_pattern ( @possible_varnames  ) {
        $re_string =~ s/(?<!\\)($bad_pattern)/\\$1/g;
    }
    return $re_string;
}

sub _safe_match_gather {
    my ( $target, $re_obj ) = @_;
    my $match = 0;
    try {
        if( $target =~ m/$re_obj/ ) {
            $match = {  # If there's a match, build an anonymous hash.
                '$<digits>' => [ 
                    map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- 
                ],
                '$+{name}'  => [
                    map { substr $target, $-[$_], $+[$_] - $-[$_] } keys %-
                ],
                '${^PREMATCH} or $`'    => ${^PREMATCH},
                '${^MATCH} or $&'       => ${^MATCH},
                '${^POSTMATCH} or $\''  => ${^POSTMATCH},
                '$^N'                   => $^N,
                '@-'                    => [ @- ],
                '@+'                    => [ @+ ],
                '%-'                    => { %- },
                '%+'                    => { %+ },
            };
        }
    } catch {
        croak "Invalid regular expression: $re_obj";
    };
    return $match;
}

1;
