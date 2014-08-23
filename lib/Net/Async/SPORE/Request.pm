package Net::Async::SPORE::Request;

use strict;
use warnings;

use URI;
use URI::QueryParam;
use URI::Escape qw(uri_escape_utf8);

sub new {
	my $class = shift;
	bless { env => { @_ } }, $class
}

sub env { shift->{env} }
sub request_method {
	my ($self) = shift;
	return $self->env->{REQUEST_METHOD} unless @_;
	$self->env->{REQUEST_METHOD} = shift;
	return $self;
}
sub script_name {
	my ($self) = shift;
	return $self->env->{SCRIPT_NAME} unless @_;
	$self->env->{SCRIPT_NAME} = shift;
	return $self;
}
sub path_info {
	my ($self) = shift;
	return $self->env->{PATH_INFO} unless @_;
	$self->env->{PATH_INFO} = shift;
	return $self;
}
sub request_uri {
	my ($self) = shift;
	return $self->env->{REQUEST_URI} unless @_;
	$self->env->{REQUEST_URI} = shift;
	return $self;
}
sub server_name {
	my ($self) = shift;
	return $self->env->{SERVER_NAME} unless @_;
	$self->env->{SERVER_NAME} = shift;
	return $self;
}
sub server_port {
	my ($self) = shift;
	return $self->env->{SERVER_PORT} unless @_;
	$self->env->{SERVER_PORT} = shift;
	return $self;
}
sub query_string {
	my ($self) = shift;
	return $self->env->{QUERY_STRING} unless @_;
	$self->env->{QUERY_STRING} = shift;
	return $self;
}
sub payload {
	my ($self) = shift;
	return $self->env->{payload} unless @_;
	$self->env->{payload} = shift;
	return $self;
}
sub params {
	my ($self) = shift;
	return $self->env->{params} unless @_;
	$self->env->{params} = shift;
	return $self;
}
sub redirections {
	my ($self) = shift;
	return $self->env->{redirections} unless @_;
	$self->env->{redirections} = shift;
	return $self;
}
sub scheme {
	my ($self) = shift;
	return $self->env->{scheme} unless @_;
	$self->env->{scheme} = shift;
	return $self;
}

sub as_request {
	my ($self) = @_;

	require HTTP::Request;
	my $uri = URI->new(
		$self->scheme . '://' . $self->server_name
	);

	my $path = $self->request_uri;

	# Apply our parameters
	my @param = @{$self->params};
	while(my ($k, $v) = splice @param, 0, 2) {
		unless($path =~ s/:$k/uri_escape_utf8($v)/ge) {
			$uri->query_param_append($k => $v);
		}
	}

	$uri->path($path);

	# Convert this into a request
	my $req = HTTP::Request->new(
		$self->request_method => $uri
	);
	$req->protocol('HTTP/1.1');
	$req->content($self->payload) if length $self->payload;

	my $env = $self->env;
	for my $k (grep /^HTTPS?_/, keys %$env) {
		my ($name) = $k =~ /^HTTPS?_(.*)/;
		$req->header($name => $env->{$k});
	}
	return $req;
}

1;
