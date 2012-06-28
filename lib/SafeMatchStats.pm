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

has explanation => (
    is  => 'ro',
);


has prematch    => (
    is => 'rw',
);

has match       => (
    is => 'rw',
);

has postmatch   => (
    is  => 'rw',
);

has carat_n     => (
    is  => 'rw',
);

has digits      => (
    is  => 'rw',

has array_minus => (
    is  => 'rw',
);

has array_plus  => (
    is  => 'rw',
)

has hash_minus  => (
    is  => 'rw',
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
#        $explanation =~ s/^The regular expression:\s+matches as follows:\s+//;
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
    return scalar $self->_safe_match_gather( $target, $re_obj );
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
    $self->matched(0);
    try {
        $self->matched( scalar $target =~ m/$re_obj/ );
    } catch {
        $self->matched( undef );
        warn "Problem in matching: $_";
    };
    if( $target =~ m/$re_obj/ ) {
            $self->matched( 1 );
            $self->digits(
                [ map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- ]
            );
            $self->hash_plus(   { %+ }        );
            $self->hash_minus(  { %- }        );
            $self->prematch(    ${^PREMATCH}  );
            $self->match(       ${^MATCH}     );
            $self->postmatch(   ${^POSTMATCH} );
            $self->carat_n(     $^N           );
            $self->array_minus( [ @- ]        );
            $self->array_plus(  [ @+ ]        );
    }
    return $self->matched
}

1;
