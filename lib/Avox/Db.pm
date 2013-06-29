package Avox::Db;
use strict;
use warnings;
use DBIx::Brev 'avox';
use base 'Exporter';
our @EXPORT=(@DBIx::Brev::EXPORT,qw(get_contacts));
sub get_contacts {
    my ($user_id) = @_;
    return sql_map {
          my ($contact_id,$login,$status) = @$_;
          $contact_id => {
            contact_id => $contact_id,
            login => $login,
            status => $status,
            messages => [],
            new_messages_count => 0,
            offline_messages_count => 0,
          }
        } q{
        select a.contact_id,b.login,coalesce(c.status,'offline') status
        from user_contacts a inner join user b on a.contact_id=b.id
        left join user_session c on a.contact_id=c.user_id
        where a.user_id=?
        },$user_id
}

1;
