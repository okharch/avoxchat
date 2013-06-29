avoxchat
========
tiny chat server & web client implementation
to demonstrate web sockets & Mojolicious

DEPLOYMENT

cpan Data::Dump DBIx::Brev Mojolicious

git clone git@github.com:okharch/avoxchat.git
cd avoxchat

# create database avox
mysql -e "create database avox"
mysql avox <db/avoxchat.sql

# ~/dbi.conf
echo "<database avox>
dsn=DBI:mysql:database=avox;host=127.0.0.1
user=root
password=**
</database>
" >~/dbi.conf

# start chat & web client server 
morbo server/avoxchat.pl
