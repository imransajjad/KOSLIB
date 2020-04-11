
GLOBAL UTIL_SHBUS_TX_ENABLED IS true.

// TX SECTION

IF NOT (DEFINED FLCS_PROC) {GLOBAL FLCS_PROC IS 0. } // required global.

local lock H to terminal:height.
local lock W to terminal:width.

global HELP_LIST is LIST(
" ",
ship:name,
"SHBUS_TX running on "+core:tag,
"command syntax:",
"...",
"help        help page 0",
"help(n)     help page n",
"comm        run command",
"comm(1,2)   run with args",
"comm str    arg is str",
"com1;com2   chain commands",
"sethost     flcs sends acks to host",
"unsethost   set/unset self as host",
"hello       hello to flcs",
"rst         reboot flcs",
"prm         reload flcs params",
"neu         neutralize controls",
"inv         invalid message").

if (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED {
    local newlist is util_wp_get_help_str().
    for i in range(0,newlist:length) {
        HELP_LIST:add(newlist[i]).
    }
}
if (defined UTIL_FLDR_ENABLED) and UTIL_FLDR_ENABLED {
    local newlist is util_fldr_get_help_str().
    for i in range(0,newlist:length) {
        HELP_LIST:add(newlist[i]).
    }
}
if (defined UTIL_HUD_ENABLED) and UTIL_HUD_ENABLED {
    local newlist is util_hud_get_help_str().
    for i in range(0,newlist:length) {
        HELP_LIST:add(newlist[i]).
    }
}

local function print_help_page_by_index {
    parameter start_line.
    local page_size is H-4.

    for i in range(start_line, start_line+page_size ) {
        if i < HELP_LIST:length {
            print "  "+HELP_LIST[i].
        }
    }
}

local function print_help_page {
    parameter page.
    local page_size is H-4.
    print_help_page_by_index(page_size*page).
}

local function print_help_by_tag {
    parameter tag.
    local hi is HELP_LIST:iterator.
    until not hi:next {
        if (hi:value:STARTSWITH(tag) ){
            print_help_page_by_index(hi:index).
            return.
        }
    }
    print "tag not found".
}

local function do_action_group_or_key {
    parameter key_in.
    if key_in = "1" {
        toggle AG1.
    } else if key_in = "2" {
        toggle AG2.
    } else if key_in = "3" {
        toggle AG3.
    } else if key_in = "4" {
        toggle AG4.
    } else if key_in = "5" {
        toggle AG5.
    } else if key_in = "6" {
        toggle AG6.
    } else if key_in = "7" {
        toggle AG7.
    } else if key_in = "8" {
        toggle AG8.
    } else if key_in = "9" {
        toggle AG9.
    } else if key_in = "0" {
        toggle AG10.
    } else if key_in = "g" {
        toggle GEAR.
    } else if key_in = "r" {
        toggle RCS.
    } else if key_in = "t" {
        toggle SAS.
    } else if key_in = "u" {
        toggle LIGHTS.
    } else if key_in = "b" {
        toggle BRAKES.
    } else if key_in = "m" {
        toggle MAPVIEW.
    } else if key_in = " " {
        print "stage manually".
    } else {
        return false.
    }
    return true.
}

local function parse_command {
    parameter commtextfull.
    if commtextfull = "" {
        return true.
    }

    for comm in commtextfull:split(";") {

        local commtext is comm:trim().
        if commtext:STARTSWITH("hello") {
            util_shbus_tx_msg("hello from FLCOM").
        } else if commtext:STARTSWITH("sethost") {
            util_shbus_tx_msg("SETHOST", core:tag ).
        } else if commtext:STARTSWITH("unsethost") {
            util_shbus_tx_msg("SETHOST", "" ).
        } else if commtext:STARTSWITH("prm"){
            util_shbus_tx_msg("RPARAM").
        } else if  commtext:STARTSWITH("help") {
            if commtext:contains(" ") {
                print_help_by_tag( (commtext:split(" ")[1]):replace(".", "") ).
            } else if commtext:length > 5 {
                print_help_page(util_shbus_raw_input_to_args(commtext)[0]).
            } else {
                print_help_page(0).
            }
        } else if commtext:STARTSWITH("rst"){
            list PROCESSORS in cpus.
            for cpu in cpus {
                if not (cpu:tag = core:tag) {
                    cpu:deactivate().
                    wait 0.1.
                    cpu:activate().
                }
            }
        } else if commtext:length = 1 and do_action_group_or_key(commtext){
            print("key "+commtext).
        } else if commtext:STARTSWITH("neu"){
            set ship:control:neutralize to true.
        } else if commtext:STARTSWITH("inv"){
            util_shbus_tx_msg("a;lsfkja;wef",list(13,4,5)).
        } else if (defined UTIL_FLDR_ENABLED) and UTIL_FLDR_ENABLED and util_fldr_parse_command(commtext) {
            print("fldr parsed").
        } else if (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED and util_wp_parse_command(commtext) {
            print("wp parsed").
        } else if (defined UTIL_HUD_ENABLED) and UTIL_HUD_ENABLED and util_hud_parse_command(commtext) {
            print("hud parsed").
        //} else if util_dev_parse_command(commtext) {
        //  print "dev parsed".
        } else {
            print("Could not parse command.").
            return false.
        }
        util_shbus_tx_get_acks().
    }
    flush_core_messages().
    return true.
}

function util_shbus_tx_get_acks {
    PARAMETER ECHO is true.
    // -1 indicates error condition ( no ack available)
    wait 0.04.
    wait 0.04.
    if not CORE:MESSAGES:EMPTY {
        local ack_msg is CORE:MESSAGES:POP:CONTENT.
        if ECHO { print ack_msg.}
        return ack_msg.
    }
    return -1.
}

function util_shbus_tx_msg {
    PARAMETER opcode_in, data_in is LIST(0).
    IF not (FLCS_PROC = 0) and NOT FLCS_PROC:CONNECTION:SENDMESSAGE(LIST(opcode_in,data_in)) {
        print("could not send message "+ arg_in).
    }
}

function util_shbus_raw_input_to_args {
    parameter commtext.

    local arg_start is commtext:FIND("(").
    local arg_end is commtext:FINDLAST(")").
    if arg_end-arg_start <= 1 {
        return list().
    }
    local arg_strings is commtext:SUBSTRING(arg_start+1, arg_end-arg_start-1):split(",").
    local numlist is list().
    for i in arg_strings {
        numlist:add( i:toscalar() ).
    }
    return numlist.
}

local COMM_STRING is core:tag:tolower()+"@"+string_acro(ship:name)+":~$".
local INPUT_STRING is "".
local comm_history is LIST().
local comm_history_MAXEL is 10.
local comm_history_CUREL is -1.

local lock str_length to COMM_STRING:length + INPUT_STRING:length.
local lock num_lines to 1+floor(str_length/W).
local current_line is H-1.
local max_lines is 1.
local cursor is 0.

local function print_overflowed_line {

    set max_lines to max(max_lines,num_lines).
    local the_line is min(current_line, H-num_lines).
    if the_line < current_line {
        print " ".
        set current_line to the_line.
    }
    
    set PAD_STRING to "":PADLEFT( W-mod(str_length,W)-1).
    if the_line +num_lines < H {
        set PAD_STRING to PAD_STRING + " ".
    }
    local print_str is (COMM_STRING+(INPUT_STRING)+PAD_STRING).
    print print_str AT(0, the_line).
    print "_" AT(mod(COMM_STRING:length+cursor,W),  the_line + floor( (COMM_STRING:length+cursor)/W)).

}

local function print_lowest_line_again {
    if (max_lines = num_lines) {
        local start is (num_lines-1)*W.
        print (COMM_STRING+INPUT_STRING):substring(start, str_length-start).
    }
}

wait 1.0.
CLEARSCREEN.
print_help_page(0).

function util_shbus_tx_get_input {
    print_overflowed_line().


    SET ch to TERMINAL:INPUT:getchar().
    IF ch = TERMINAL:INPUT:RETURN {
        
        print_lowest_line_again().
        parse_command(INPUT_STRING).
        
        comm_history:ADD(INPUT_STRING).
        if comm_history:LENGTH > comm_history_MAXEL {
            set comm_history to comm_history:sublist(1,comm_history_MAXEL).
            set comm_history_CUREL to comm_history_MAXEL-1.
        } else {
            set comm_history_CUREL to comm_history:LENGTH-1.
        }

        SET INPUT_STRING TO "".
        set current_line to H-1.
        set max_lines to 1.
        set cursor to 0.

    } ELSE IF ch = terminal:input:UPCURSORONE {
        if comm_history_CUREL >= 0 {
            SET INPUT_STRING TO comm_history[comm_history_CUREL].
            SET comm_history_CUREL TO comm_history_CUREL-1.
            set cursor to INPUT_STRING:length.
        }
    } ELSE IF ch = terminal:input:DOWNCURSORONE {
        if comm_history_CUREL+1 < comm_history:LENGTH {
            SET INPUT_STRING TO comm_history[comm_history_CUREL+1].
            SET comm_history_CUREL TO comm_history_CUREL+1.
            set cursor to INPUT_STRING:length.
        }
    } ELSE IF ch = terminal:input:BACKSPACE {
        IF (cursor > 0) and (cursor <= INPUT_STRING:length)  {
            SET INPUT_STRING TO INPUT_STRING:REMOVE(cursor-1 ,1).
            set cursor to max(cursor-1,0).
        }
    } ELSE IF ch = terminal:input:LEFTCURSORONE {
        set cursor to max(cursor-1,0).
    } ELSE IF ch = terminal:input:RIGHTCURSORONE {
        set cursor to min(cursor+1,INPUT_STRING:length).
    } ELSE {
        //CLEARSCREEN.
        //SET INPUT_STRING TO INPUT_STRING+ch.
        set INPUT_STRING to INPUT_STRING:insert(cursor, ch).
        set cursor to cursor+1.
    }
}


function util_shbus_tx_do_command {
    parameter comm_string is "".

    if comm_string = "" {
        print "util_shbus_tx_do_command invalid param".
    } else {
        parse_command(comm_string).
    }
}

// TX SECTION END
