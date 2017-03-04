# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Kgc-MQ.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 4;
BEGIN { use_ok('Kgc::MQ') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $mq;
eval{
	$mq = Kgc::MQ->new({
		'name' => 'my test queue'
		,'handle type' => 'read and write'
	});
};
my $error = $@;
if($error){
	warn "There was an error:[$error]\n";
	print "Bailing out!\n";
}

ok($mq->file_descriptor > 0,'Testing file descriptor');
ok($mq->finish,'Closing queue connection');
ok($mq->remove,'Unlinking the queue connection');


my ($writemq,$readmq);
eval{
	$writemq = Kgc::MQ->new({
		'name' => 'my test queue'
		,'handle type' => 'write only'
	});
	$readmq = $writemq->spawn_reader();
};
$error = $@;
if($error){
	warn "There was an error:[$error]\n";
	print "Bailing out!\n";
}


# do server test
my $pid = fork();

my @testmessages = (
	pack('S',443243).'N'
	,'This is the first message.'
	,'I love alphabet soup.'
	,"Eat my nuggets.
		If only I spoke French."
	,"Berries only blossom on Uranus."
	,'Seriously, lose the butter.'
);

use IO::Select;

if($pid > 0){
	# parent (let it be the server)
	my $failedmsgs = 0;
	my $numOfmsgs = scalar(@testmessages);
	my $sel = IO::Select->new($readmq->file_descriptor() );
	while($sel->can_read(1)){
		my $msg = $readmq->dequeue();
		warn "Server has received\n---\n|$msg|\n---\n\n";
		$failedmsgs = 1 if $msg eq shift(@testmessages) ;		
	}
}
elsif($pid == 0){
	# child (let it be the server)
	#warn "Sleeping for 2 seconds";
	
	foreach my $i (@testmessages){
		#warn "Client is sending message [".length($i)."]\n";
		$writemq->enqueue($i);
			
		if($writemq->flush_enqueue() ){
			warn "Client successfully sent message.\n";
		}
		else{
			warn "Client failed to send message.\n";
		}
	}
	exit;
}
else{
	# failed to fork
	warn "Bailing out!";
	
}
# kill the server process
sleep 5;
kill(2,$pid);

$writemq->finish;
$writemq->remove;





