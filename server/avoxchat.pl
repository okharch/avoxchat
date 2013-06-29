use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojolicious::Lite;
use JSON qw(encode_json decode_json);
use Avox::Db;
use Data::Dump qw(dump);

# this is websocket chat server /register /login /chat
my (%clients);

post '/register' => sub {
    my ($self) = @_;
    my ($login,$password, $p2) = map $self->param($_)||undef,qw(login password p2);
    unless (grep defined,$login,$password, $p2==3 && $password eq $p2) {
        $self->flash(message => 'Some parameters are invalid!');
        $self->redirect_to('register');
        return 0;
    }
    if (sql_value("select count(*) from user where login=?",$login)) {
        $self->flash(message => 'This login is already used!');
        $self->redirect_to('register');
        return 0;        
    }
    #$app->log->debug($app->dumper({foo => 'bar'}));
    sql_exec "insert into user(login,password) values (?,password(?))",$login,$password;
    $self->flash(message => 'User successfuly registered, please login');
    $self->redirect_to('login');
};

post '/login' => sub {
    my $self = shift;
    my ($login,$password) = map $self->param($_)||undef,qw(login password);
    my $user_id = sql_value("select id from user where login=? and password=password(?)",$login, $password);
    if ($user_id) {
        $self->session->{user_id} = $user_id;
        sql_exec "insert ignore into user_session(user_id,server_id) values(?,?)",$user_id,current_server();
        $clients{$user_id} = 1;
        $self->redirect_to('/');
        return 0;
    }
    $self->flash(message => 'Wrong login/password');
    $self->redirect_to('login');    
};

sub send_json {
    my ($tx,$hash) = @_;
    my $json = encode_json($hash);
    app->log->debug(sprintf 'send_json: %s', $json);
    $tx->send($json);
    app->log->debug(sprintf 'sent_json: %s', $json);
}

sub send_to_contacts {
    my ($user_id,$hash) = @_;
    $hash->{user_id} = $user_id;
    my @contacts = sql_query q{
    select a.contact_id
    from user_contacts a inner join user_session b on a.contact_id=b.user_id
    where a.user_id=?
    }, $user_id;
    @contacts = grep exists $clients{$_}, @contacts;
    # send to all active clients who has $user in their contact list
    send_json( $clients{$_}, $hash ) for @contacts;
}
    
websocket '/chat' => sub {
    my $self = shift;
    my $user_id = $self->session->{user_id};
    Mojo::IOLoop->stream($self->tx->connection)->timeout(600); # increase timeout to 5 minutes
    app->log->debug(sprintf 'Client %s connected: %s', $user_id, $self->tx);
    my $mytx = $self->tx;
    $clients{$user_id} = $mytx;
    send_to_contacts $user_id, { event => 'online', user_id => $user_id };
    $self->on(json => 
        sub {
            my ($self,$hash) = @_;
            app->log->debug(sprintf 'json event: %s', dump($hash));
            my $event = $hash->{event};
            $hash->{user_id} = $user_id;
            if ($event eq 'message') {
                my $contact_id = $hash->{contact_id};
                send_json($clients{$contact_id},$hash); # send message to client
            } else {
                die "event $event is not supported by server";
            }
        }
    );

    $self->on(finish =>
        sub {
            app->log->debug('Client disconnected');
            delete $clients{$user_id};
            sql_exec "delete from user_session where user_id=?", $user_id;
            send_to_contacts $user_id, { event => 'offline', user_id => $user_id };
        }
    );
};

# this is web client UI
get '/' => sub {
    my $self = shift;
    my $user_id = $self->session->{user_id};
    $self->redirect_to('login') and return 0 unless $user_id && $clients{$user_id};
    app->log->debug('user_id: '.$user_id);        
    my $user = sql_hash("select id,login from user where id=?",$user_id);
    my $contacts = encode_json {get_contacts($user_id)};
    app->log->debug('contacts: '.$contacts);        
    app->log->debug('u: '.encode_json $user);        
    $self->stash( contacts => $contacts, u => encode_json $user, user_name => $user->{login} );
    $self->render('index');
};

get '/logout' => sub {
    my $self = shift;
    delete $self->session->{user_id};
    delete $self->session->{contact_id};
    $self->redirect_to('login');
};

get '/register' => 'register';

get '/login' => 'login';

app->start;

sub current_server { 1 }

__DATA__

@@ index.html.ep
% my $user = session 'user';
% my $user_id = session 'user_id';
<h1><%= $user_name %> chat</h1>
<table>
<tr>
<td>
<label for="contacts">Contacts</label>:<br>
<select id="contacts" size=12 onclick="set_sel_contact(this)">
</select>
<td><div id=messages_area>
<label for=messages>Messages</label>
<br>
<textarea id=messages cols=70 rows=10>
</textarea>
<br>
<label for=send_message>Send Message:</label>
<input type=text id=message size=40>
<input type=button value="Send Message" onclick="send_message()">
</div>
</table>

<script type="text/javascript" src="js/jquery.min.js"></script>
<script type="text/javascript" >
var user_id = <%= $user_id %>;
var contacts = <%== $contacts %>;
var sel_contact_id; // selected contact
var u = <%== $u %>;

function show_lines(m,c,status) {
    var r = "";
    if (m) {
        var o = m.length - c;
        for (var i=0; i<m.length; i++) {
            r += m[i] + (i>=o?"[" + status + "]":"") + "\n";
        }
    }
    return r;
}

function set_sel_contact() {
    sel_contact_id = $('#contacts').val();
    console.log('sel_contact_id');
    console.log(sel_contact_id);
    if (sel_contact_id) {
        show_messages();
    } else {
        hide_messages();
    }
}

function hide_messages() {
    $('#messages_area').hide();
}

function show_messages() {
    $('#messages_area').show();
    var contact = contacts[sel_contact_id];
    console.log('show_messages sel_contact_id');
    console.log(contact);
    var text;    
    if (contact.offline_messages_count) {
        text = show_lines(contact.messages,contact.offline_messages_count,'offline');    
    } else if (contact.new_messages_count) {
        text = show_lines(contact.messages,contact.new_messages_count,'new');
    } else {
        text = show_lines(contact.messages,1,'sent');
    }
    contact.new_messages_count = 0;
    $('#messages').val(text);
}

function show_contacts() {
    var options='';
    for (var contact_id in contacts) {
        var contact = contacts[contact_id];
        var o = contact.offline_messages_count;
        o = o? " offline[" + o +"]":"";
        var n = contact.new_messages_count;
        n = n? " new["+n+"]" : "";
        var option = contact.login + " [" + contact.status + "]" + o + n;
        options += '<option value='+contact_id+
            (contact_id==sel_contact_id? ' selected' : '')+
            '>'+option+"</option>\n";
    }
    document.getElementById("contacts").innerHTML = options;
    set_sel_contact();
}

function send_message() {
    var c = contacts[sel_contact_id];
    var m = c.messages;
    var msg = now()+' ' + u.login + ' :'+$("#message").val();
    m.push(msg);    
    if (c.status == 'offline') {
        c.offline_messages_count++;
    } else {
        c.offline_messages_count=1;
        send_omessages(c);
    }
    show_contacts();
}

function send_omessages(contact) {
    if (contact.offline_messages_count) {
        var m = contact.messages;
        var o = m.length - contact.offline_messages_count;
        console.log('offset: '+o);
        for (var i = o; i<m.length; i++) {
            var json = JSON.stringify({'event':'message','contact_id':contact.contact_id,'message':m[i]});
            console.log('msg json: '+json);
            ws.send(json);
        }
        contact.offline_messages_count = 0;
    }
}

function now() {
    var t = new Date();
    return t.toString().replace(/(GMT.\d+).*/,'$1');
}

var ws;

$(function () {

show_contacts();
ws = new WebSocket('ws://localhost:3000/chat');
ws.onopen = function () {
  console.log('Connection opened');
};

ws.onmessage = function (msg) {
  var res = JSON.parse(msg.data);
  console.log('onmessage');
  console.log(res);
  var c = contacts[res.user_id];
  console.log('contact');
  console.log(c);
  if (res.event == 'online') {
    c.status = 'online';
    send_omessages(c);
  } else if (res.event == 'offline') {
    c.status = 'offline';
  } else if (res.event == 'message') {    
    c.messages.push(res.message);
    c.new_messages_count++;
  }
  show_contacts();
};

ws.onclose = function () {
    location = '/login';
}

}); // ready
</script>

@@ login.html.ep
<h1>Login</h1>
% if (my $msg = flash 'message') {
    <b><%= $msg %></b><br>
% }
<form method=post>
<p>
<label for=login>Login</label>
<input type=text size=20 name=login id=login/>
<label for=password>Password</label>
<input type=password size=20 name=password id=password/>
<input type=submit value="Submit"/>
</p>
</form>

@@ register.html.ep
<h1>Register</h1>
<form method=post>
<p>
<label for=login>Login</label>
<input type=text size=20 name=login id=login/>
<br>
<label for=password>Password</label>
<input type=password size=20 name=password id=password/>
<br>
<label for=p2>Repeat Password</label>
<input type=password size=20 name=p2 id=p2/>
<br>
<input type=submit value=Submit/>
</p>
</form>

