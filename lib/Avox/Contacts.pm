package IRC::Contacts;
use strict;
use warnings;
use IRC::Db;

sub add_contact { sql_exec "replace into user_contacts(user_id,contact_id) values (?,?)",@_ }

sub del_contact { sql_exec "delete from user_contacts where user_id=? and contact_id=?",@_ }

sub get_contacts {
    sql_query q{
    select a.contact_id,coalesce(b.status,'offline'),b.server_ip    
    from user_contacts a left join user_session b on a.contact_id=b.user_id
    where a.user_id=?
    },@_;
}

1;
