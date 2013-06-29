package IRC::UserSession;

use strict;
use warnings;
use IRC::Db;

my %user_sessions;

sub user_connect {
    my ($user_id) = @_;
    sql_exec "replace into user_session(user_id,server_id) values(?,?)", $user_id, current_server_id();
    update_user_status($user_id,'online');
}

sub user_disconnect {
    my ($user_id) = @_;
    sql_exec "delete from user_session where user_id=?",$user_id;
    update_user_status($user_id,'offline');
}

sub user_send_message {
    my ($user_from,$user_to,$message) = @_;
    my $server_id = sql_value "select server_id from user_session where user_id=?",$user_to;
    return 501 unless $user_server; # user is offline
    rpc_call($server_id,'send_message', user_id => $user_to, user_from => $user_from, message => $message);
}

sub update_user_status {
    my ($user_id,$status) = @_;
    my $contacts = sql_value "select contacts from users where id=?",$user_id;
    $contacts = join ",",unpack "L*", $contacts;
    my @online = sql_query "select user_id,server_id from user_session where user_id in ($contacts)";
    rpc_call($_->[1],'update_contacts','user_id'=>$_->[0],'contact_id'=>$user_id,status=>$status) for @online;
}

1;