package SafeMatchStats;

use Moo;
use Sub::Quote;

use v5.14;
use utf8;

use Try::Tiny;
use Safe;
use Carp;

use YAPE::Regex::Explain;

our $VERSION = 0.01;

has regexp_obj => (
    is => 'ro',
);

has captures => (
    is  => 'rw',
);

has explanation => (
    is  => 'ro',
);


sub BUILDARGS {
    my( $class, @args ) = @_;
    my $args_hash = $args[0];
    croak "Must pass a hashref to $class\->new()."
        if ref $args_hash ne 'HASH';
    croak "Usage: $class\->new( { regexp_str => 'PATTERN' " .
          "[, regexp_mods => '[msixadlu^-]+' } )"
        if ! exists $args_hash->{regexp_str};
    my $regexp_obj
        = $class->_safe_qr( $args_hash->{regexp_str}, $args_hash->{regexp_mods} );
    croak "Couldn't generate a valid regexp object."
        if ! ref $regexp_obj eq 'Regexp';
    my $explanation;
    try {
        $explanation = YAPE::Regex::Explain->new($regexp_obj)->explain;
        $explanation =~ s/^The regular expression:\s+matches as follows:\s+//;
    } catch {
        $explanation = q{};
    };
    return {
        regexp_obj  => $regexp_obj,
        explanation => $explanation,
    };
}

sub match {
    my( $self, $target ) = @_;
    my $re_obj = $self->regexp_obj;
    my $match = $self->_safe_match_gather( $target, $re_obj );
    return if ! defined $match;     # An exception was thrown during match.
    if( $match && ref $match eq 'HASH' ) {
        $self->captures( $match );
    }
    return $match ? 1 : 0;
}


sub _safe_qr {
    my( $self, $regexp, $modifiers ) = @_;
    $regexp    = $self->_sanitize_re_string( $regexp );
    $modifiers = $self->_sanitize_re_modifiers( $modifiers );
    my $compartment = Safe->new;
    ${ $compartment->varglob('regexp') } = $regexp;
    my $re_obj = $compartment->reval( 'my $safe_reg = qr/$regexp/;' );
    return if $@;   # Return undef if 'reval' caught an exception.
    return $re_obj; # Otherwise return a regexp object.
}

sub _sanitize_re_modifiers {
    my( $self, $modifiers ) = @_;
    return '' if ! defined $modifiers;
    $modifiers =~ tr/msixadlu^-//cd;
    my @modifiers = split //, $modifiers;
    my %seen;
    return join '', grep { ! $seen{$_}++ } @modifiers;
}
sub _sanitize_re_string {
    my ( $self, $re_string ) = @_;
    no warnings 'qw';
    my @possible_varnames = qw%
        \$\^\w          \@ENV              \$ENV
        \$[0()<>#!+-]   \$\{[\w()<>+-]}    \@\{\w+}
    %;
    foreach my $bad_pattern ( @possible_varnames  ) {
        $re_string =~ s/(?<!\\)($bad_pattern)/\\$1/g;
    }
    return $re_string;
}

sub _safe_match_gather {
    my ( $self, $target ) = @_;
    my $re_obj = $self->regexp_obj;
    my $match = 0;
    my $result;
    try {
        $result = $target =~ m/$re_obj/;
    } catch {
        $match = undef;
        warn "Problem in matching: $_";
    };
    if( $target =~ m/$re_obj/ ) {
        $match = {  # If there's a match, build an anonymous hash.
            '$<digits>' => [ 
                map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- 
            ],
            '$+{name}'  => { %+ },
            '$-{name}'  => { %- },
            '${^PREMATCH}'  => ${^PREMATCH},
            '${^MATCH}'     => ${^MATCH},
            '${^POSTMATCH}' => ${^POSTMATCH},
            '$^N'           => $^N,
            '@-'            => [ @- ],
            '@+'            => [ @+ ],
        };
    }
    return $match;
}

1;
