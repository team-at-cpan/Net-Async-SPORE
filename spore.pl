#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Async::Loop;
use Net::Async::HTTP;
use JSON::MaybeXS;
use File::Spec;

my $json = JSON::MaybeXS->new;
my $file = shift;
open my $fh, '<:encoding(UTF-8)', $file or die "$file - $!";
my $txt = do { local $/; <$fh> };
my $api = $json->decode($txt);

my $loop = IO::Async::Loop->new;
my $ua = Net::Async::HTTP->new;
$loop->add($ua);
my $m = $api->{methods}{list_repos};

my %param = (
	username => 'tm604',
);
my $path = $m->{path};
for my $k (@{$m->{required_params}}) {
	$path =~ s/:$k/$param{$k}/g;
}
use URI;
my $uri = URI->new(
	$api->{base_url},
);
$uri->path(
	File::Spec->catdir(
		$uri->path,
		$path
	)
);
my $req = HTTP::Request->new(
	GET => $uri
);
$req->header($_ => $api->{headers}{$_}) for keys %{$api->{headers}||{}};
$ua->do_request(
	request => $req
)->then(sub {
	my $resp = shift;
	my $data = $json->decode($resp->decoded_content);
	for my $repo (@$data) {
		printf "%s %s %s %d\n", $repo->{name}, $repo->{description}, $repo->{updated_at}, $repo->{open_issues_count};
	}
	Future->wrap;
})->get;
