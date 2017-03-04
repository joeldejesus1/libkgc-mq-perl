package Kgc::MQ;

#use 5.014002;
use strict;
use warnings;
use Carp;
use Digest::MD5;


require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Kgc::MQ ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.2';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Kgc::MQ::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Kgc::MQ', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=item new

Please supply Kgc::MQ->new({
	'name' => 'my queue'
	,'handle type' => 'read and write'
})

=cut
our %handletypes = (
	'read only' => 1
	,'write only' => 2
	,'read and write' => 3
);

sub new {
	my $package = shift;
	my $options = shift;
	die "faulty options" unless
		defined $options && ref($options) eq 'HASH';
	my $name = $options->{'name'};
	my $handletype = $options->{'handle type'};
	unless(defined $handletype && $handletypes{$handletype}){
		die "not a proper handle type.($handletype)";
	}
	$handletype ||= 'read and write';
	
	 
	my $this = {'handle type' => $handletype};
	if(defined $name && length($name) > 4 && $name =~ m/^(.*)$/ ){
		$this->{'name'} = $1;		
	}

	
	$this->{'no hash'} = $options->{'no hash'};
	
	# open_queue('/newq', length('/newq'), 0, 10, MAX_SIZE)
	bless($this,$package);
	
	$this->_fetch_system_constants();
	
	if(defined $options->{'file descriptor'} && $options->{'file descriptor'} =~ m/^(\d+)$/){
		$this->{'file descriptor'} = $1;
	}
	elsif(!defined $options->{'file descriptor'} && defined $this->{'name'}){
		$this->_set_up_queue();
	}
	else{
		die "badly formatted file descriptor";
	}
	
	
	return $this;
}

=item _derive_name

Hash, then untaint the name.

=cut

sub _hashed_name{
	my $this = shift;
	my $md5name = Digest::MD5::md5_hex($this->name);
	
	# untaint
	if($md5name =~ m/^(.*)$/){ $md5name = $1; }
	return $md5name;
}

=item _set_up_queue

=cut

sub _set_up_queue{
	my $this = shift;

	my $name;
	if($this->{'no hash'}){
		if($this->name =~ m/^([0-9a-zA-Z][0-9a-zA-Z\.\-]+[0-9a-zA-Z])$/){
			$name = $1;
		}
		else{
			die "bad format for name=$name";
		}
	}
	else{
		$name = $this->_hashed_name();
	}
	# open_queue('/newq', 0, maxmsg, msgsize,3)
	# Call the C function
	my $filedesc = open_queue(
		'/'.$name
		,0
		,$this->msg_max()
		,$this->msgsize_max()
		,$handletypes{$this->{'handle type'}} 
	);
	
	if( defined $filedesc  && $filedesc > 0){
		return $this->{'file descriptor'} = $filedesc;
	}
	else{
		die "object failed to load";
		
	}
}



=item _fetch_system_constants

=cut

sub _fetch_system_constants {
	my $this = shift;
	my %lookups = (
		'msg_max' => '/proc/sys/fs/mqueue/msg_max'
		,'msgsize_max' => '/proc/sys/fs/mqueue/msgsize_max'
		,'queues_max' => '/proc/sys/fs/mqueue/queues_max'
	);
	
	foreach my $k (keys %lookups){
		
		open(my $fhout, '<',$lookups{$k}) || die "cannot find system constants";
		my $response = '';
		while(<$fhout>){  $response .= $_;	}
		close $fhout || die "cannot close file handle";
		chomp($response);
		# untaint
		if($response =~ m/^(\d+)$/){ $response = $1; }
		else{ die "faulty value ($response)";}
		$this->{'constants'}->{$k} = $response;
	}
	return 1;
}

=item finish

=cut

sub finish {
	my $this = shift;	
	my $result = close_queue($this->file_descriptor());
	if(defined $result && $result > 0){
		# success
		return 1;
	}
	else{
		# failed
		return 0;
	}
}

=item remove

Complete delete the queue from the system. 

=cut

sub remove {
	my $this = shift;
	my $result = unlink_queue('/'.$this->_hashed_name());
	if(defined $result && $result > 0){
		return 1;
	}
	else{
		#failed
		return 0;
	}
		
}

=item DESTROY

=cut

sub DESTROY {
	my $this = shift;
	return $this->finish();
}



################### Getters/Setters ######################

=item file descriptor

=cut

sub file_descriptor {
	my $this = shift;
	return $this->{'file descriptor'};
}


=item name

=cut

sub name {
	my $this = shift;
	return $this->{'name'};
}

=item  msg_max

=cut

sub msg_max{
	my $this = shift;
	return $this->{'constants'}->{'msg_max'};
}

=item msgsize_max

=cut

sub msgsize_max{
	my $this = shift;
	return $this->{'constants'}->{'msgsize_max'};	
}

=item queues_max

=cut

sub queues_max{
	my $this = shift;
	return $this->{'constants'}->{'queues_max'};	
}


##################### Actions #####################

=item spawn_reader

Create another mq object, but with read only attributes.

=cut

sub spawn_reader {
	my $this = shift;
	return $this->spawn('read only');
}

=item spawn_writer 

=cut

sub spawn_writer {
	my $this = shift;
	return $this->spawn('write only');
}

=item spawn

=cut

sub spawn {
	my $this = shift;
	my $handletype = shift;
	warn "Handle:$handletype\n";
	return Kgc::MQ->new({
		'name' => $this->name()
		,'handle type' => $handletype
	});
}

=item flush_enqueue

Do this when we are sure that the queue socket is writable.

=cut

sub flush_enqueue {
	my $this = shift;
	
	my $arrayref = $this->{'enqueue_array'};
	unless(
		defined $arrayref
		&& ref($arrayref) eq 'ARRAY'
		&& scalar(@{$arrayref}) > 0	
	){
		return undef;
	}
	
	while(my $message = shift(@{$arrayref})){
		my $msglength = length($message);
		unless($msglength > 0){
			#warn "Message is too short";
			next;
		}
		# send_message(file descriptor, message, length(message))
		#warn "enqueue MQ: |$message|\n";
		return undef unless send_message($this->file_descriptor,$message);
	}
	return 1;
}


=item enqueue

Do not send ' ', because this represents a null return.

This does not automatically send any messages into the file handle.  For that, we have to flush.

=cut

sub enqueue {
	my $this = shift;
	my $message = shift;
	unless(length($message) > 0){
		return undef;
	}
	unless(
		defined $this->{'enqueue_array'}
		&& ref($this->{'enqueue_array'}) eq 'ARRAY'
	){
		$this->{'enqueue_array'} = [];
	}
	push(@{$this->{'enqueue_array'}}, $message);
	return scalar(@{$this->{'enqueue_array'}});
}


=item dequeue

=cut

sub dequeue {
	my $this = shift;
	return receive_message($this->file_descriptor,$this->msgsize_max);
}

=item send

A very simple send subroutine.

=cut

sub send{
	my ($this,$message) = @_;
	return 0 unless defined $message && 0 < length($message) && length($message) < $this->msgsize_max;
	return 0 unless 0 < $this->file_descriptor;
	return send_message($this->file_descriptor,$message);
}

=item receive

A very simple receive subroutine.

=cut

sub receive{
	my ($this) = @_;
	return undef unless 0 < $this->file_descriptor;
	return receive_message($this->file_descriptor,$this->msgsize_max);
}

1;

__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Kgc::MQ - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Kgc::MQ;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Kgc::MQ, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joel Dejesus, E<lt>joeldejesus@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Joel Dejesus

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
