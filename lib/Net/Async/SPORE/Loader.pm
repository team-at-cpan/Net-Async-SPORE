package Net::Async::SPORE::Loader;

use strict;
use warnings;

=head1 NAME

Net::Async::SPORE::Loader - loads SPORE API definitions

=head1 SYNOPSIS

 my $api = Net::Async::SPORE::Loader->new_from_file(
  'sample.json',
  transport => 'Net::Async::HTTP',
  class     => 'Sample::API',
 );
 $api->some_request(x => 123, y => 456)->get;

=head1 DESCRIPTION

This is the API loader class. It'll read in definitions and create classes in memory.

=cut

use Net::Async::SPORE::Request;
use Net::Async::SPORE::Definition;

use JSON::MaybeXS;
use File::Spec;

sub inject_method(&@);

=head1 METHODS

=cut

=head2 new_from_file

Instantiate a new API object from the given file.

 my $api = Net::Async::SPORE::Loader->new_from_file(
  'sample.json',
  transport => 'Net::Async::HTTP',
  class     => 'Sample::API',
 );
 $api->some_request(x => 123, y => 456)->get;

=cut

sub new_from_file {
	my ($class, $file, %args) = @_;

	my $api = do {
		open my $fh, '<', $file or die "$file - $!";
		my $txt = do { local $/; <$fh> };
		decode_json($txt);
	};
	$class->new($api, %args);
}

=head2 new

Instantiates an API object from a definition provided as a hashref.

 my $api = Net::Async::SPORE::Loader->new(
  { ... },
  transport => 'Net::Async::HTTP',
  class     => 'Sample::API',
 );
 $api->some_request(x => 123, y => 456)->get;

=cut

sub new {
	my ($class, $api, %args) = @_;

	$args{class} ||= $class->_next_api_class;

	{
		no strict 'refs';
		push @{$args{class} . '::ISA'}, qw(Net::Async::SPORE::Definition);
	}

	inject_method {
		$api->{'base_url'}
	} $args{class} => '_base_url';
	inject_method {
		$api->{'headers'}
	} $args{class} => '_headers';

	$class->apply_methods(
		%args,
		spec => $api
	);
	$args{class}->new
}

=head1 METHODS - Internal

You're welcome to use these, but you probably don't need them.

=head2 apply_methods

Applies the API methods to the target class.

=cut

sub apply_methods {
	my ($self, %args) = @_;
	my $spec = delete $args{spec} or die 'need a spec';
	my $class = delete $args{class} or die 'need a class';
	my %methods = %{$spec->{methods}};
	for my $method (keys %methods) {
		my $method_spec = $methods{$method};
		inject_method {
			my ($self, %args) = @_;

			if(my @missing = grep !exists $args{$_}, @{$method_spec->{required_params}}) {
				die "Missing parameters: " . join ',', @missing;
			}

			# Start with the path template
			my $path = $method_spec->{path};

			# Apply our parameters
			my @param = map {;
				$_ => $args{$_}
			} @{$method_spec->{required_params}};
			push @param, $_ => $args{$_} for grep exists $args{$_}, @{$method_spec->{optional_params}};

			# We now have enough info to construct the endpoint URI
			my $uri = URI->new(
				$self->_base_url,
			);
			$uri->path(
				File::Spec->catdir(
					$uri->path,
					$path
				)
			);

			my @hdr;
			{
				my %hdr = %{$self->_headers};
				for (sort keys %hdr) {
					(my $mapped = $_) =~ s/-/_/g;
					push @hdr, "HTTP_$mapped" => $hdr{$_};
				}
			}

			my $rq = Net::Async::SPORE::Request->new(
				# UPPER CASE FOR THAT FORTRAN FEELING
				REQUEST_METHOD => $method_spec->{method},
				SCRIPT_NAME    => '',
				PATH_INFO      => $uri->path,
				REQUEST_URI    => $uri->path_query,
				SERVER_NAME    => $uri->host,
				SERVER_PORT    => $uri->port || ($uri->scheme eq 'https' ? 443 : 80),
				QUERY_STRING   => '',

				# yes, consistency is not a bad thing either
				payload        => '',
				params         => \@param,
				redirections   => [],
				scheme         => $uri->scheme,
				@hdr,
			);

			# Pass this on to whatever our defined handler
			# is. Middleware may be involved.
			$rq->as_request;
			$self->_request($rq->as_request);
		} $class => $method;
	}
	$self
}

=head1 FUNCTIONS

=head2 inject_method

Helper function for adding a method to the given
class.

 inject_method($target_class, $method_name, $code);

Will raise an exception if the method is already there.

=cut

sub inject_method(&@) {
	my ($code, $class, $method) = @_;
	no strict 'refs';
	die "Method overlap for $method" if $class->can($method);
	*{join '::', $class, $method} = $code;
}

{
my $next_id = 'AA001';

=head2 _next_api_class

Returns an autogenerated class name.

=cut

sub _next_api_class { 'Net::Async::SPORE::API::' . $next_id++ }
}

1;

__END__

=head1 AUTHOR

Tom Molesworth <cpan@perlsite.co.uk>

=head1 LICENSE

Copyright Tom Molesworth 2012-2015. Licensed under the same terms as Perl itself.

