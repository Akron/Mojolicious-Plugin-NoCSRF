#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
  our @INC;
  unshift(@INC, '../../lib', '../lib');
};

use Test::More;
use Test::Mojo;

use Mojolicious::Lite;
use Mojo::ByteStream 'b';

get '/1' => sub {
  my $c = shift;
  return $c->render(
    text => $c->nocsrf_form_for('test', sub { 'ghfghh' })
  );
};


get '/2' => sub {
  my $c = shift;
  return $c->render(inline => <<'TEMPLATE');
%= nocsrf_form_for 'test', begin
%= number_field 'age'
% end
TEMPLATE
};


get '/test/:feed' => sub {
  return shift->render(text => 'fun');
} => 'feed';


get '/3' => sub {
  my $c = shift;
  return $c->render(
    text => $c->nocsrf_url_for('feed', feed => 'puh')
  );
};

get '/4' => sub {
  my $c = shift;
  return $c->render(
    text => $c->nocsrf_url_for('http://www.google.com/')
  );
};


get('/5')->over('nocsrf')->to(
  cb => sub {
    my $c = shift;
    return $c->render(text => 'Fine');
  });

get '/5' => sub {
  shift->render(text => 'Not fine');
};

get '/get_url' => sub {
  my $c = shift;
  my $url = $c->param('url');
  $c->render(text => $c->nocsrf_url_for($url));
};

get '/6' => sub {
  my $c = shift;
  if ($c->nocsrf) {
    return $c->render(text => 'Fine');
  };
  return $c->render(text => 'Not fine');
};

any [qw/GET POST/] => '/7' => sub {
  my $c = shift;
  if ($c->req->method eq 'GET') {
    return unless $c->reply->nocsrf;
    return $c->render(text => 'Fine');
  }
  else {
    return unless $c->nocsrf_redirect_to;
    return $c->redirect_to('/fine');
  };
  return $c->render(text => 'fail');
};



my $t = Test::Mojo->new;
my $app = $t->app;


$app->plugin('NoCSRF');

ok($app->nocsrf_token, 'Token is okay');
is(length($app->nocsrf_token), 16, 'Token is okay');

ok($app->nocsrf_token, 'Token is okay');
is(length($app->nocsrf_token), 16, 'Token is okay');

ok($app->nocsrf_token, 'Token is okay');
is(length($app->nocsrf_token), 16, 'Token is okay');

# nocsr_form_for
$t->get_ok('/1')
  ->element_exists('form[action=test]')
  ->element_exists('form input')
  ->element_exists('form input[name=nocsrf]')
  ->element_exists('form input[type=hidden]')
  ->element_exists('form input[value]');

Mojo::IOLoop->stop;

$t->get_ok('/2')
  ->element_exists('form[action=test]')
  ->element_exists('form input')
  ->element_exists('form input[name=nocsrf]')
  ->element_exists('form input[type=hidden]')
  ->element_exists('form input[value]')
  ->element_exists('form input[name=age]')
  ->element_exists('form input[type=number]');


# nocsrf_url_for
$t->get_ok('/3')->content_like(qr!^/test/puh\?nocsrf=.{16}$!);

$t->get_ok('/4')->content_like(qr!^http://www\.google\.com/\?nocsrf=.{16}$!);


$t->get_ok('/5')->content_is('Not fine');
my $url = $t->ua->get('/get_url?url=/5')->result->body;
$t->get_ok($url)->content_is('Fine');


$t->get_ok('/6')->content_is('Not fine');
$url = $t->ua->get('/get_url?url=/6')->result->body;
$t->get_ok($url)->content_is('Fine');


$t->get_ok('/7')
  ->text_is('head title', '403')
  ->text_is('h1', 403)
  ->text_is('div.notify', 'No valid request')
  ->status_is(403);

$url = $t->ua->get('/get_url?url=/7')->result->body;
$t->get_ok($url)->content_is('Fine');

$t->post_ok('/7')
  ->status_is(302)
  ->header_like('Location', qr!/7$!);

$t->post_ok($url)
  ->status_is(302)
  ->header_like('Location', qr!/fine$!);




done_testing;
exit;

