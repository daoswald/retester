package SafeMatchStats;

use Moo;

use v5.12;
use utf8;
use feature qw( unicode_strings );

use Try::Tiny;
use Capture::Tiny qw( capture );
use Safe;
use Carp;

our $VERSION = 0.01;


# Constructor:
has regex        => ( is => 'ro', required => 1 );  # User input (constructor).
has modifiers    => ( is => 'ro'                );  # User input (constructor).

has regexp_str   => ( is => 'rw', lazy => 1, builder => \&_gen_re_string );
has regexp_obj   => ( is => 'rw', lazy => 1, builder => \&_safe_qr       );

# Set by a call to do_match().
has target       => ( is => 'rw', lazy => 1, default => sub { q{} } );
has capture_dump => ( is => 'rw' );
has matched      => ( is => 'rw', default => sub{ undef } );

# Captures
my @attribs = qw/   prematch    match       postmatch   carat_n     digits  
                    array_minus array_plus  hash_minus  hash_plus           /;

foreach my $attrib ( @attribs  ) {
    has $attrib => ( 
        is      => 'ro', lazy    => 1, 
        builder => sub{ 
            return $_[0]->matched ? $_[0]->capture_dump->{$attrib} : undef;
        }
    );
}

# Debug: The debugger dump from match.
has debug_info  => ( is => 'rw', lazy => 1, default => \&_debug_info );

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    return $class->$orig( @args )
        unless @args == 1 && ! ref $args[0] eq 'HASH';
    return $class->$orig( regex => $_[0] );
};

sub do_match {
    my ( $self, $target ) = @_;
    $self->target( $target // $self->target );
    return scalar $self->_safe_match_gather( $self->target, $self->regexp_obj );
}

sub _gen_re_string {
    my $self = shift;
    my $re_str = $self->_sanitize_re_string(     $self->regex     );
    my $mod_str = $self->_sanitize_re_modifiers( $self->modifiers );
    return "(?$mod_str:$re_str)";
}

sub _sanitize_re_string {
    my ( $self, $re_string ) = @_;
    no warnings 'qw';
    my @bad_varnames = qw%    \$\^\w    \@ENV    \$ENV
      \$[0()<>#!+-]    \$\{[\w()<>+^-]}    \@\{\w+}     %;
    $re_string =~ s/(?<!\\)($_)/\\$1/g foreach @bad_varnames;
    return $re_string;
}

sub _sanitize_re_modifiers {
    my ( $self, $modifiers ) = @_;
    return '' if !defined $modifiers;
    $modifiers =~ tr/msixadlu^-//cd;
    my @modifiers = split //, $modifiers;
    my %seen;
    return join '', grep { !$seen{$_}++ } @modifiers;
}

sub _safe_qr {
    my $self = shift;
    my $compartment = Safe->new;
    ${ $compartment->varglob('regexp') } = $self->regexp_str;
    my $re_obj =
      $compartment->reval('my $safe_reg = qr/$regexp/;');
    return if $@;    # Return "undef" if 'reval' caught an exception.
    return $re_obj;  # Otherwise return a regexp object.
}

sub _safe_match_gather {
    my $self = shift @_;
    my $target = $self->target;
    my $re_obj = $self->regexp_obj;
    $self->matched(0);
    try {
        $self->matched(1) if $target =~ m/$re_obj/;
        if( $self->matched ) {
            $self->match_dump( {
                digits    => 
                    [ map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- ],
                hash_plus => {%+},
                hash_minus => {%-},
                prematch   => ${^PREMATCH},
                match      => ${^MATCH},
                postmatch  => ${^POSTMATCH},
                carat_n    => $^N,
                array_minus => [ @- ],
                array_plus  => [ @+ ],
            } );
        }
    }
    catch {
        $self->matched(undef);
        warn "Problem in matching: $_";
    };

    return $self->matched;
}

sub _debug_info {
    my $self = shift;
    my $rv;
    my( undef, $stderr, undef ) = capture { 
        try {
            use re q/debug/;
            my $regex = $self->regexp_str;
            $rv = $self->target =~ m/$regex/;
        }
        catch {
            s/\sat\s[\w.]+\sline\s\d+\.$/./;
            print STDERR "$_\n";
            $rv = undef;
        };
        $rv;
    };
    return $stderr;
}

1;
