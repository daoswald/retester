#!/usr/bin/env perl
use Mojolicious::Lite;

use lib 'lib';

use SafeMatchStats;

any '/' => sub {
  my $self = shift;
  $self->stash( result => undef );
  if( $self->param('regexp') ) {
      my $result = match_gather( 
        $self->param('target'), 
        $self->param('regexp'), 
        $self->param('modifiers') 
    );
    $self->stash( result => $result );
  }
  $self->render('index');
};


app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Perl Regexp Tester';
<h1>Perl Regexp Tester</h1>
<p>
Test Perl regular expressions against target strings.
</p>
<p>
The regexp engine used is compatible with Perl <%= " $^V" =%>.
</p>
%= form_for '/' => ( method => 'post' ) => begin
  <p>
    Target string:
    <br />
    %= text_area 'target', cols => 80, placeholder => 'Target string'
  </p>
  <p>
    Regular Expression:
    <br />
    %= text_area 'regexp', cols => 80, placeholder => 'Regular Expression'
    <br />
    <small>Example: To test "<code>m/pattern/</code>", enter "<code>pattern</code>" 
    (without quotes).</small>
  </p>
  <p>
    Flags:
    <br />
    <%= text_field 'flags', cols        => '30', 
                            placeholder => 'Valid Modifiers: [msixadlu]',
                            maxlength   => '8'
    %>
  </p>
    %= submit_button
%end

<%= ref $result eq 'HASH' && dumper $result %>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
