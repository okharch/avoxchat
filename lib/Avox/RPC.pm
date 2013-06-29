package IRC::RPC;
use strict;
use warnings;
use base 'Exporter';
use JSON qw(encode_json decode_json);
use IRC::Db;
use LWP::UserAgent;

use LWP::Simple;
{
    my %servers;
    sub init_servers {
        %servers = sql_map {@$_} q{select id,url from server};
    }
    init_servers;
    sub server {
        my ($server_id) = @_;
        init_servers unless $servers{$server_id};
        die "server $server_id not found" unless $servers{$server_id};
        $servers{$server_id};
    }
}

sub rpc {
    my ($server_id,$proc_name,%param) = @_;
    $param{rpc_procname} = $proc_name;
    my $json = encode_json(\%param);
    my $server = server($server_id);
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(POST => "http://$server");
    $req->content_type('application/x-www-form-urlencoded');
    $req->content("json=$json");
    my $response = $ua->request($request);
}

1;