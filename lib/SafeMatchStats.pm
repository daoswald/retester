package SafeMatchStats;

use strict;
use warnings;
use Moo;
use v5.12;
use utf8;
use feature qw( unicode_strings );
use Try::Tiny;
use Capture::Tiny qw( capture );
use Safe;
use Carp;

our $VERSION = 0.01;

use constant ALARM_TIMEOUT    => 2;
use constant ALARM_RESET      => 0;
use constant MAX_DEBUG_LENGTH => 16384;
use constant MAX_QUANTIFIERS  => 25;

has regex => ( is => 'ro', required => 1 );    # User input (constructor).
has modifiers => ( is => 'ro' );               # User input (constructor).
has g_modifier => ( is => 'ro', lazy => 1, builder => '_has_g_modifier' );
has regexp_str => ( is => 'ro', lazy => 1, builder => '_gen_re_string' );
has regexp_obj => ( is => 'ro', lazy => 1, builder => '_safe_qr' );
has bad_regex  => ( is => 'rw' );
has target     => ( is => 'rw', lazy => 1, default => sub { q{} } );
has _capture_dump => ( is => 'rw' );
has matched       => ( is => 'rw', default => sub { undef } );
has debug_info    => ( is => 'ro', lazy => 1, default => \&_debug_info );
# Captures
my @attribs = qw/   prematch    match       postmatch   carat_n     digits
  array_minus array_plus  hash_minus  hash_plus   match_rv /;

foreach my $attrib (@attribs) {
    has $attrib => (
        is      => 'ro',
        lazy    => 1,
        default => sub {
            return $_[0]->matched ? $_[0]->_capture_dump->{$attrib} : undef;
        }
    );
}

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    return $class->$orig(@args)
      if @args != 1 || ref $args[0] eq 'HASH';
    return $class->$orig( regex => $_[0] );
};

sub do_match {
    my ( $self, $target ) = @_;
    $self->target( $target // $self->target );
    return scalar $self->_safe_match_gather;
}

sub _gen_re_string {
    my $self    = shift;
    $self->bad_regex(0);
    my $re_str  = $self->_sanitize_re_string( $self->regex );
    my $mod_str = $self->_sanitize_re_modifiers( $self->modifiers );
    return "(?$mod_str:$re_str)";
}

sub _sanitize_re_string {
    my ( $self, $re_string ) = @_;
    no warnings 'qw';    ## no critic(warnings)
    my $count = 0;
    $count++ while $re_string =~ /(?<!\\)(?:[*+]|\{\d,\d*\})/g;
    if( $count > MAX_QUANTIFIERS ) {
        $self->bad_regex(1);
        warn "Bad bad!\n";
        return '[1-0]Disallowed regex pattern';
    }
    my @bad_varnames = qw%    \$\^\w         \@ENV             \$ENV
      \$[0<>#!+-]    \$\{[\w<>+^-]}    \@\{\w+}     %;
    $re_string =~ s/(?<!\\)($_)/\\$1/gxsm foreach @bad_varnames;
    return $re_string;
}

sub _has_g_modifier {
    my $self = shift;
    return 0 if !$self->modifiers || !$self->modifiers =~ m/g/;
    return 1;
}

sub _sanitize_re_modifiers {
    my ( $self, $modifiers ) = @_;
    return q{} if !defined $modifiers;
    $modifiers =~ tr/msixadlu^-//cd;
    my @modifiers = split //, $modifiers;
    my %seen;
    return join q{}, grep { !$seen{$_}++ } @modifiers;
}

sub _safe_qr {
    my $self        = shift;
    return if $self->bad_regex;
    my $compartment = Safe->new;
    ${ $compartment->varglob('regexp') } = $self->regexp_str;
    my $re_obj = $compartment->reval('my $safe_reg = qr/$regexp/;');
    if( $@ ) {
        $self->bad_regex(1);
        return; # Return "undef" if 'reval' caught an exception.
    }
    return $re_obj;  # Otherwise return a regexp object.
}

sub _safe_match_gather {
    my $self   = shift;
    my $target = $self->target;
    my $re_obj = $self->regexp_obj;

    # Can't do a match if the regexp didn't compile.
    
    return $self->matched(undef) 
        if index( ref($re_obj), 'Regex' ) < 0 || $self->bad_regex;
    $self->matched(0);
    try {
        alarm ALARM_TIMEOUT;
        my @match_rv;
        # Using logical short circuit operators because we can't have our
        # special match variables falling out of an if(){} block scope.
        $self->g_modifier
          && ( (@match_rv) = $target =~ m/$re_obj/g )
          && ( $self->matched( @match_rv ? 1 : 0 ) );
        !$self->g_modifier
          && $target =~ m/$re_obj/
          && $self->matched(1);
        if ( $self->matched ) {
            $self->_capture_dump(
                {
                    digits => [
                        map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#-
                    ],
                    hash_plus   => {%+},
                    hash_minus  => {%-},
                    prematch    => ${^PREMATCH},
                    match       => ${^MATCH},
                    postmatch   => ${^POSTMATCH},
                    carat_n     => $^N,
                    array_minus => [@-],
                    array_plus  => [@+],
                    match_rv    => [@match_rv],
                }
            );
        }
        alarm ALARM_RESET;
    }
    catch {
        $self->matched(undef);
        carp "Match threw an exception: $_";
        alarm ALARM_RESET;
    };
    return $self->matched;
}

sub _debug_info {
    my $self = shift;
    return 'Invalid regular expression.'
      if index( ref( $self->regexp_obj ), 'Regex' ) < 0 || $self->bad_regex;
    my ( $rv, @rv );
    my $stderr;
    try {
        alarm ALARM_TIMEOUT ;
        ( undef, $stderr, undef ) = capture {
            try {
                use re q/debug/;
                my $regex = $self->regexp_str;
                if ( $self->g_modifier ) {
                    @rv = $self->target =~ m/$regex/g;
                }
                else {
                    $rv = $self->target =~ m/$regex/;
                }
            }
            catch {
                print STDERR 'Exception thrown during debug: ',
                  _remove_diag_linenums($_), "\n";
            };
        };
        alarm ALARM_RESET ;
    } 
    catch { 
        carp $_;
        alarm ALARM_RESET ;
    };
    if( length $stderr > MAX_DEBUG_LENGTH ) {
        $stderr = substr( $stderr, 0, MAX_DEBUG_LENGTH ) 
        . "\n<<< Output Truncated. >>>\n";
    }
    return $stderr;
}

sub _remove_diag_linenums {
    my $message = shift;
    $message =~ s/\sat\s.+$/.../;
    return $message;
}

1;
