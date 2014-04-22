package Juju::RPC;
# ABSTRACT: RPC Class
$Juju::RPC::VERSION = '0.5';

use AnyEvent;
use AnyEvent::WebSocket::Client;
use JSON;

use Moo;
use namespace::clean;

has 'conn' => (is => 'rw');

has 'request_id' => (is => 'rw', default => 0);

has 'is_connected' => (is => 'rw', default => 0);

sub create_connection {
    my $self = shift;
    die "Already Connected."
      if $self->is_connected and $self->is_authenticated;
    my $client = AnyEvent::WebSocket::Client->new(ssl_no_verify => 1);
    $self->is_connected(1);
    $self->conn($client->connect($self->endpoint)->recv);
}


sub close {
    my $self = shift;
    $self->conn->close;
}

sub call {
    my ($self, $params, $cb) = @_;
    my $done = AnyEvent->condvar;

    # Increment request id
    $self->request_id($self->request_id + 1);
    $params->{RequestId} = $self->request_id;
    $self->conn->send(encode_json($params));
    $self->conn->on(
        each_message => sub {
            $done->send(decode_json(pop->decoded_body)->{Response});
        }
    );
    $cb->($done->recv);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Juju::RPC - RPC Class

=head1 VERSION

version 0.5

=head1 DESCRIPTION

Contains methods and attributes not meant to be accessed directly but
utilized by the exposed API.

=head1 ATTRIBUTES

=head2 conn

Connection object

=head2 request_id

An incremented ID based on how many requests performed on the connection.

=head2 is_connected

Check if a websocket connection exists

=head1 METHODS

=head2 creation_connection

Initiate a websocket connection and stores itself in C<conn> attribute.

=head3 Returns

Websocket connection

=head2 close

Close connection

=head2 call

Sends event to juju api server

=head3 Takes

C<params> - Hash of parameters needed to query Juju API

C<cb> - (optional) callback routine

=head3 Returns

Result of RPC Response

=head1 AUTHOR

Adam Stokes <adamjs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Adam Stokes.

This is free software, licensed under:

  The MIT (X11) License

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
