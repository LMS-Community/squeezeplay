/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/
#define RUNTIME_DEBUG 1

#include "common.h"
#include "ui/jive.h"


/*
 * IR input will cause the following events to be sent:
 * EVENT_IR_DOWN - sent as soon as a new code has been sent
 * EVENT_IR_REPEAT - sent out as fast as ir codes are received after IR_DOWN occurs
 * EVENT_IR_PRESS - sent when no new codes are received (or a new key is pressed) prior to the IR_HOLD_TIMEOUT time
 * EVENT_IR_HOLD - sent once when ir input occurs and the IR_HOLD_TIMEOUT time has been exceeded
 * EVENT_IR_UP - sent when input stops (IR_KEYUP_TIME exceeded) or the ir code changes
 */



/* button hold threshold .9 seconds - HOLD event is sent when a new ir code is received after IR_HOLD_TIMEOUT ms*/
#define IR_HOLD_TIMEOUT 900


/* time after which, if no additional ir code is received, a button input is considered complete */
#define IR_KEYUP_TIME 128

/* This ir code used by some remotes, such as the boom remote, to indicate that a code is repeating */
#define IR_REPEAT_CODE 0

/* time that new ir input has occurred (using the input_event time as the time source) */
Uint32 ir_down_millis = 0;

/* time that the last ir input was received (using the input_event time as the time source)*/
Uint32 ir_last_input_millis = 0;

/* last ir code received */
Uint32 ir_last_code = 0;

bool ir_received_this_loop = false;

static enum jive_ir_state {
	IR_STATE_NONE,
	IR_STATE_DOWN,
	IR_STATE_HOLD_SENT,
} ir_state = IR_STATE_NONE;



static Uint32 queue_ir_event(Uint32 ticks, Uint32 code, JiveEventType type) {
	JiveEvent event;

	memset(&event, 0, sizeof(JiveEvent));

	event.type = type;
	event.u.ir.code = code;
	event.ticks = ticks;
	jive_queue_event(&event);

	return 0;
}


static int ir_handle_up() {
	if (ir_state != IR_STATE_HOLD_SENT) {
		//odd to use sdl_getTicks here, since other ir events sent input_event time - code using PRESS and UP shouldn't care yet about the time....
		queue_ir_event(jive_jiffies(), ir_last_code, (JiveEventType) JIVE_EVENT_IR_PRESS);
	}

	ir_state = IR_STATE_NONE;
	queue_ir_event(jive_jiffies(), ir_last_code, (JiveEventType) JIVE_EVENT_IR_UP);
	
	ir_down_millis = 0;
	ir_last_input_millis = 0;
	ir_last_code = 0;
	
	return 0;
}

static int ir_handle_down(Uint32 code, Uint32 time) {
	ir_state = IR_STATE_DOWN;
	ir_down_millis = time;

	queue_ir_event(time, code, (JiveEventType) JIVE_EVENT_IR_DOWN);
					
	return 0;
}


void ir_input_code(Uint32 ir_code, Uint32 input_time) {
	bool repeat_code_sent = false;
						
	ir_received_this_loop = true;
			
	if (ir_code == IR_REPEAT_CODE) {
		if (ir_state == IR_STATE_NONE) {
			/* ignore, since we have no way to know what 
			 * key was sent.
			 */
			return;
		}

		ir_code = ir_last_code;   
		repeat_code_sent = true;
	}

	/* did ir code change, if so complete the old code */
	if (ir_state != IR_STATE_NONE && ir_code != ir_last_code) {
		ir_handle_up();
	}

	switch (ir_state) {
	case IR_STATE_NONE:
		ir_handle_down(ir_code, input_time);
		break;

	case IR_STATE_DOWN:
	case IR_STATE_HOLD_SENT: 
		/* pump's up check might not have kicked in yet, so we
		 * need the check for a quick second press.
		 */
		if (!repeat_code_sent && input_time >= ir_last_input_millis + IR_KEYUP_TIME) {
			/* quick second press of same key occurred: complete 
			 * the first, start the second. though if repeat code
			 * is sent, we always know that it is not a quick.
			 */
			ir_handle_up();
			ir_handle_down(ir_code, input_time);
			break;
		}
				
		queue_ir_event(input_time, ir_code, (JiveEventType) JIVE_EVENT_IR_REPEAT);

		if (ir_state == IR_STATE_DOWN && input_time >= ir_down_millis + IR_HOLD_TIMEOUT) {
			ir_state = IR_STATE_HOLD_SENT;
			queue_ir_event(input_time, ir_code, (JiveEventType) JIVE_EVENT_IR_HOLD);
		}
		break;
	}

	ir_last_input_millis = input_time;
	ir_last_code = ir_code;
}


void ir_input_complete(Uint32 now) {
	/* Now that we've handled the ir input, determine if ir input has
	 * stopped.
	 */
	if (!ir_received_this_loop && ir_last_input_millis && (now >= IR_KEYUP_TIME + ir_last_input_millis)) {
		ir_handle_up();
	}

	ir_received_this_loop = false;
}
