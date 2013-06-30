# create two client connections and communicate to each other
use Test::More;
use Test::Mojo;

# Include application
use FindBin;
require "$FindBin::Bin/../server/avoxchat.pl";

# login l2
my $t2 = Test::Mojo->new;
# login l2
$t2->post_ok('/login' => form => {login => 'l2',password=>'p2'})
->status_is(302) # redirect
->websocket_ok('/chat');

# login l1
my $t1 = Test::Mojo->new;
$t1->post_ok('/login' => form => {login => 'l1',password=>'p1'})
->status_is(302)
->websocket_ok('/chat');

my $message = {contact_id=>1,user_id=>2,event=>"message",message=>'hello'};
$t2
->message_ok
->json_message_is({"user_id"=>"1","event"=>"online"})
->send_ok({json => $message})
;

$t1
->message_ok
->json_message_is($message);
;

$t2->tx->finish;

$t1
->message_ok
->json_message_is({"user_id"=>"2","event"=>"offline"})
;

=pod
# get index
$t1->get_ok('/')
    ->status_is(200)
    ->content_like(qr/user_id = 1/);


=pod
$t2->websocket_ok('/echo')
  ->send_ok('Hello Mojo!')
  ->message_ok
  ->message_is('echo: Hello Mojo!')
  ->finish_ok;
=cut
done_testing();
