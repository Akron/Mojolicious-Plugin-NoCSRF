package Mojolicious::Plugin::NoCSRF;
use Mojo::Base 'Mojolicious::Plugin';

# See: https://docs.djangoproject.com/en/dev/ref/csrf/#how-csrf-works

our $VERSION = '0.04';

# Todo: Make nocsrf_render to reply->nocsrf

# Register plugin
sub register {
  my ($plugin, $app, $param) = @_;

  $param ||= {};

  # Load parameter from Config file
  if (my $config_param = $app->config('NoCSRF')) {
    $param = { %$param, %$config_param };
  };

  # Add internationalization
  $app->plugin(Localize => {
    dict => {
      NoCSRF => {
        error => {
          _ => sub { $_->locale },
          -en => 'No valid request',
          de  => 'Keine gültige Anfrage'
        }
      }
    }
  });

  # Load notifications plugin
  unless (exists $app->renderer->helpers->{notify}) {
    $app->plugin('Notifications');
  };

  # Load RandomString plugin with specific parametrization
  $app->plugin('Util::RandomString' => {
    nocsrf_token => {
      alphabet => '2345679bdfhmnprtFGHJLMNPRT',
      length => ($param->{token_length} || 16)
    }
  });

  # Establish 'nocsrf' route condition
  $app->routes->add_condition(
    nocsrf => sub { return $_[1]->nocsrf }
  );

  # Establish 'nocsrf_form_for' helper
  # Based on CSRFProtect
  $app->helper(
    nocsrf_form_for => sub {
      my $c = shift;

      my $h = $c->helpers;

      # The form has a callback
      if ( defined $_[-1] && ref( $_[-1] ) eq 'CODE' ) {
        my $cb = $_[-1];

        # Add hidden field
        $_[-1] = sub {
          $c->hidden_field(nocsrf => $h->nocsrf_token) . "\n" . $cb->();
        };
      }

      # Return form
      return $h->form_for(@_);
    });


  # Establish 'nocsrf_url_for' helper
  $app->helper(
    nocsrf_url_for => sub {
      my $c = shift;
      my $h = $c->helpers;
      return $h->url_for(@_)->query([ nocsrf => $h->nocsrf_token ]);
    }
  );


  # Establish 'nocsrf_token' helper
  $app->helper(
    nocsrf_token => sub {
      my $c = shift;

      # Get token from stash or session
      my $token = $c->stash('nocsrf') || $c->session('nocsrf');
      return $token if $token;

      # Generate new token
      $token = $c->random_string('nocsrf_token');

      $c->session(nocsrf => $token);
      $c->stash(nocsrf => $token);
      return $token;
    }
  );

  # Establish 'nocsrf' helper
  $app->helper(
    nocsrf => sub {
      my $c = shift;

      # Get nocsrf token
      my $param = (
        scalar $c->param('nocsrf') ||
          $c->req->headers->header('X-NoCSRF')
        ) or return;

      my $session = $c->session('nocsrf') or return;
      return if $session ne $param;
      return 1;
    }
  );


  # Establish 'nocsrf_redirect_to' helper
  $app->helper(
    nocsrf_redirect_to => sub {
      my $c = shift;

      my $h = $c->helpers;

      # No attack detected
      return 1 if $h->nocsrf;

      $h->notify(error => $h->loc('NoCSRF_error'));
      $c->redirect_to(@_);
      return;
    }
  );


  # Establish 'nocsrf_render' helper
  $app->helper(
    'reply.nocsrf' => sub {
      my $c = shift;

      # No attack detected
      return 1 if $c->nocsrf;

      $c->notify(error => $c->loc('NoCSRF_error'));
      $c->res->code(403);

      $c->render(scalar @_ ? @_ : (inline => <<'TEMPLATE'));
<!DOCTYPE html>
<html>
  <head><title>403</title></head>
  <body>
    <h1>403</h1>
%= notifications 'html'
  </body>
</html>
TEMPLATE

      return;
    }
  );
};


1;


__END__

=pod

=head1 NAME

Mojolicious::Plugin::NoCSRF - Defend Cross-Site-Request-Forgery Attacks with Control


=head1 SYNOPSIS

  # Mojolicious::Lite
  plugin 'NoCSRF';

  # In routes
  any '/information' => ('nocsrf') => sub {
    shift->render(text => 'Fine!');
  };

  # In template
  %= nocsrf_form_for '/check' => begin
  %= text_input 'example'
  % end

  # In controllers
  return $c->render(text => 'Fail!') unless $c->nocsrf;

=head1 DESCRIPTION

L<Mojolicious::Plugin::NoCSRF> is yet another Cross-Site-Request-Forgery
attack protection plugin for Mojolicious.
There is a bunch of other plugins on CPAN, with all having different
design goals and using different approaches (see L<Alternatives|/ALTERNATIVES>).

The reason I created another one was, that all other
plugins available have a strict and application wide security concept,
while I had the need for a plugin only securing
some aspects of my application without interfering any others.


=head1 METHODS

L<Mojolicious::Plugin::NoCSRF> inherits all methods from L<Mojolicious::Plugin>
and implements the following new one.

=head2 register

  plugin NoCSRF => {
    token_length => 20
  };

Called when registering the plugin.
Accepts a parameter C<token_lenghth>, defining the length of the token in characters.
Defaults to C<16>.
All parameters can be set either on registration or as part
of the configuration file with the key C<NoCSRF>
(with the configuration file having the higher precedence).




=head1 ROUTE CONDITIONS

=head2 nocsrf

  # Mojolicious::Lite
  any '/information' => ('nocsrf') => sub {
    shift->render(text => 'Fine!');
  };

  # Mojolicious
  my $r = $app->routes;
  $r->post('/information')->over('nocsrf')->to(cb => sub {
    shift->render(text => 'Fine!');
  });


The C<nocsrf> route condition checks, if a C<NoCSRF> token exists
(either as a URL or POST parameter or a header) and if it is valid.
The route cannot be passed otherwise.


=head1 HELPERS

=head2 nocsrf

 return $c->render(text => 'Fail!') unless $c->nocsrf;

Compares the NoCSRF token, given as a parameter or as
a C<X-NoCSRF> header, with the session value.
Returns a true value, if no CSRF attack can be identified,
otherwise a false value is returned.


=head2 nocsrf_form_for

  # In templates:
  %= nocsrf_form_for '/check' => (method => 'POST'), begin
  %= text_input 'example'
  % end

Taghelper for form creation.
Accepts the same parameters as
L<form_for|Mojolicious::Plugin::TagHelpers/form_for>
and automatically introduces a hidden nocsrf token value.


=head2 nocsrf_url_for

  # In Controllers
  print $c->nocsrf_url_for('my-route');

  # In templates
  %= nocsrf_url_for '/check'

Taghelper for url creation.
Accepts the same parameters as
L<url_for|Mojolicious::Controller/url_for>
and automatically appends a C<nocsrf> token parameter.


=head2 nocsrf_token

  my $token = $c->nocsrf_token;

Returns the session depending csrf protection token,
to be used, e.g. for protection of Ajax requests.

The token is base26 encoded to prevent random strings containing
possibly insulting words, in case they are used as visible
URL parameters.


=head2 nocsrf_redirect_to

  return unless $c->nocsrf_redirect_to;
  return unless $c->nocsrf_redirect_to('/invalid');

In case the L<nocsrf|/nocsrf> test fails, the user is
redirected to the current url or a given path or url.

An C<error> notification will contain an error message.


=head2 reply->nocsrf

  return unless $c->reply->nocsrf;
  return unless $c->reply->nocsrf('invalid');

In case the L<nocsrf|/nocsrf> test fails, a template
is rendered with the error code C<403>.
If no template name is given, a default template is rendered

An C<error> notification will contain an error message.

This reply method is EXPERIMENTAL.


=head1 AJAX REQUESTS

L<Mojolicious::Plugin::NoCSRF> has no special Ajax helper,
but supports the C<X-NoCSRF> header as an alternative to the
C<noscrf> parameter.

To secure an Ajax request, you could simply add this header to
the C<XMLHttpRequest> object, maybe introduced as a meta tag
in the underlying HTML document.

  <meta name="nocsrf" value="<%= nocsrf_token %>" id="nocsrf" />
  <!-- ... -->
  <script>
    var r = new XMLHttpRequest();
    r.setRequestHeader(
      "X-NoCSRF",
      document.getElementById('nocsrf').getAttribute('value')
    );
    // ...
  </script>


=head1 ALTERNATIVES

The following plugins are alternatives to L<Mojolicious::Plugin::NoCSRF>.

=over 4

=item *

L<CSRFDefender|Mojolicious::Plugin::CSRFDefender>

This plugin parses all response bodies for forms to protect,
and for each request it hooks into the C<before_dispatch>
and C<after_dispatch> hooks. The design goal is to protect
your users automagically without the need for changing your
code. However, it does not protect requests other than C<POST>.


=item *

L<DeCSRF|Mojolicious::Plugin::DeCSRF>

All URLs that need to be protected are centrally defined
in this plugin using regular expressions. This means,
there is less magic, but makes the approach unfortunately rather
inflexible. Also it applies the C<before_dispatch> hook, meaning it
interferes with the whole application.


=item *

L<CSRFProtect|Mojolicious::Plugin::CSRFProtect>

This plugin overwrites the default C<form_for> helper
and checks all non-C<GET> or -C<HEAD> request for a valid
CSRF token. This is a good solution for websites, but not good
for applications that provide a RESTful API. It also has no
first class support for C<GET> protection. It applies the
C<before_route> hook and thus interferes the whole application.

=back


These plugins are great for CSRF protection without the need of
writing code in controllers. L<Mojolicious::Plugin::NoCSRF>
needs additional code in controllers, but by giving you more control
regarding the protection level.


=head1 DEPENDENCIES

L<Mojolicious>,
L<Mojolicious::Plugin::Localize>,
L<Mojolicious::Plugin::Util::RandomString>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-NoCSRF


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013-2016, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
