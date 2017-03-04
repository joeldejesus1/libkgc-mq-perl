#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <mqueue.h>

#include "ppport.h"

#include "const-c.inc"
// open_queue('/newq', 0, maxmsg, msgsize,3)
// mq is an unsigned long as a file descriptor (so, let's cast it to an integer)
// read only = 1, write only = 2, both = 3
int open_queue(char* name,int flags, int maxmsg, int msgsize, int handletype){
    mqd_t mq;
    struct mq_attr attr;
    /* initialize the queue attributes */
    attr.mq_flags = flags;
    attr.mq_maxmsg = maxmsg;
    attr.mq_msgsize = msgsize;
    attr.mq_curmsgs = 0;
    if(handletype == 1){
    	// read only
    	mq = mq_open(name, O_CREAT | O_RDONLY, 0600, &attr);
    }
    else if(handletype == 2){
    	// write only
    	mq = mq_open(name, O_CREAT | O_WRONLY, 0600, &attr);
    }
    else if(handletype == 3){
    	// read and write
    	mq = mq_open(name, O_CREAT | O_RDWR, 0600, &attr);
    }
    else{
    	return -1;
    }
    
    if((mqd_t)-1 == mq ){
    	return -1;
    }
    else{
    	return (int) mq;
    }
}

int close_queue(int filedesc){
	mqd_t mq = (mqd_t) filedesc;
	if((mqd_t)-1 == mq_close(mq)){
		return -1;
	}
	else{
		return 1;
	}
}

int unlink_queue(char* name){
	if((mqd_t)-1 == mq_unlink(name)){
		return -1;
	}
	else{
		return 1;
	}
}
// send_message(file descriptor, message, length(message))
// http://compgroups.net/comp.lang.perl.misc/passing-scalars-to-c-functions/376387
int send_message(int filedesc,SV* message){
	mqd_t mq = (mqd_t) filedesc;
	
	STRLEN len;
	unsigned char* msg1 = (unsigned char*) SvPV(message,len);
	
	if(len == 0){
		return 0;
	}
	
	//fprintf(stderr,"\n^^^^\n",len,buffer);
	if( mq_send(mq,msg1,len,1) == 0){
		return 1;
	}
	else{
		return 0;
	}	
}

// receive_message(int filedesc,int msg_size)
SV* receive_message(int filedesc,int max_size){
	mqd_t mq = (mqd_t) filedesc;
	unsigned char buffer[max_size];
	ssize_t bytes_read = mq_receive(mq, buffer,(size_t) max_size, NULL);
	unsigned char* answer;
	if(bytes_read > 0){
		// we got a message
		answer = malloc(bytes_read * sizeof(unsigned char*));
		memcpy(answer,buffer,bytes_read);
		return (SV*) newSVpv(answer,bytes_read);
	}
	else{
		return &PL_sv_undef;
	}
	
}

MODULE = Kgc::MQ		PACKAGE = Kgc::MQ		

INCLUDE: const-xs.inc

int
open_queue(name,flags,maxmsg,msgsize,handletype)
	char* name
	int flags
	int maxmsg
	int msgsize
	int handletype
	
int
close_queue(filedesc)
	int filedesc

int
unlink_queue(name)
	char* name

SV*
receive_message(filedesc,msg_size)
	int filedesc
	int msg_size

int 
send_message(filedesc,message)
	int filedesc
	SV* message