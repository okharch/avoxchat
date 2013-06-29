package IRC::Users;
use strict;
use warnings;
use IRC::Db;

sub add_contact {
    my ($user_id,$contact_id) = @_;
    my @contacts = unpack "L*", sql_query "select contacts from users where id=?", $user_id;
    @contacts = sort {$a <=> $b} uniq $contact_id, @contacts;
    sql_exec "update userreplace user(id,contactsinto "
}

sub del_contact {
    my ($user_id,$contact_id) = @_;
    
}

sub get_contacts {
    my ($user_id) = @_;
    # return users & their statuses (online/no disturb/etc)
}

1;
