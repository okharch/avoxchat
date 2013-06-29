package IRC::UserSessions;
my %user_sessions;
sub user_connect {
    my ($user_id) = @_;
    sql_exec "replace into "
}

sub user_disconnect {
    my ($user_id) = @_;
    
}

sub user_send_message {
    my ($user_from,$user_to) = @_;
}

sub 