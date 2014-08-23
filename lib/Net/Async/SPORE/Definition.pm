package Net::Async::SPORE::Definition;
use strict;
use warnings;
use JSON::MaybeXS;

sub new { my $class = shift; bless { @_ }, $class }

sub _transport {
	my $self = shift;
	return $self->{transport} if $self->{transport};

	# If we didn't have a transport, set one up -
	# this is not the recommended usage and will
	# probably change in future.
	require IO::Async::Loop;
	require Net::Async::HTTP;

	my $loop = IO::Async::Loop->new;
	$loop->add(
		$self->{_transport} = Net::Async::HTTP->new
	);
	$self->{_transport}
}

sub _request {
	my ($self, $req) = @_;
	$self->_transport->do_request(
		request => $req
	)->transform(
		done => sub { decode_json(shift->content) }
	)
}

1;
