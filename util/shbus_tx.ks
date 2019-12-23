
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_FLDR_ENABLED) { GLOBAL UTIL_FLDR_ENABLED IS false.}
GLOBAL UTIL_SHBUS_TX_ENABLED IS true.

// TX SECTION

// SET FLCS_PROC TO 0. required global.

local HELP_COMM_LIST is LIST(
"hello.  send_hello().",
"inv.  invalid message.",
""
).

local function print_help_str {
    parameter help_text is HELP_COMM_LIST.
    SET i TO help_text:ITERATOR.
    UNTIL NOT i:NEXT {
        PRINT "  "+i:VALUE.
    }
    
}

local function print_help {
    PRINT "list of valid commands: ".
    print_help_str().
    print_help_str(util_fldr_get_help_str()).
    print_help_str(util_wp_get_help_str()).
}

local function get_single_command_end {
    parameter commtextfull.

    local brackount is 0.
    local index is 0.
    until index = commtextfull:LENGTH {
        if commtextfull[index] = "(" { set brackount to brackount+1.}
        if commtextfull[index] = ")" { set brackount to brackount-1.}
        if commtextfull[index] = "." and brackount = 0 {
            return index.
        }
        set index to index + 1.
    }
    return -1.
}

local function parse_command {
    parameter commtextfull.
    if commtextfull = "" {
        return true.
    }

    local first_end is get_single_command_end(commtextfull).
    local commtext is commtextfull:SUBSTRING(0,first_end+1).
    local commtextnext is "".
    if commtextfull:length > first_end+1 {
        set commtextnext to commtextfull:SUBSTRING(first_end+1,commtextfull:length-first_end-1).
    }

    if commtext:STARTSWITH("hello") {
        util_shbus_tx_msg("hello from FLCOM").
    } else if  commtext:STARTSWITH("help") {
        print_help().
    } else if commtext:STARTSWITH("inv."){
        util_shbus_tx_msg("a;lsfkja;wef",list(13,4,5)).
    } else if UTIL_FLDR_ENABLED and util_fldr_parse_command(commtext) {
        print "fldr parsed".
    } else if UTIL_WP_ENABLED and util_wp_parse_command(commtext) {
        print "wp parsed".
    //} else if util_dev_parse_command(commtext) {
    //  print "dev parsed".
    } else {
        PRINT "Could not parse command.".
        return false.
    }
    return parse_command(commtextnext).
}

function util_shbus_tx_msg {
    PARAMETER opcode_in, data_in is LIST(0).
    IF NOT FLCS_PROC:CONNECTION:SENDMESSAGE(LIST(opcode_in,data_in)) {
        PRINT "could not send message "+ arg_in.
    }
}

function util_shbus_raw_input_to_args {
    parameter commtext.

    SET arg_start TO commtext:FIND("(").
    SET arg_end TO commtext:FINDLAST(")").
    SET arg_strings TO commtext:SUBSTRING(arg_start+1, arg_end-arg_start-1):split(",").
    set numlist to list().
    for i in arg_strings {
        numlist:add( i:toscalar() ).
    }
    return numlist.
}

local INPUT_STRING is "".
local OLD_INPUT_STRING is "".

function util_shbus_get_input {
    PRINT "":PADLEFT(TERMINAL:WIDTH) AT(0,floor((8+INPUT_STRING:length)/TERMINAL:WIDTH)).
    PRINT "COMM->: "+INPUT_STRING AT(0,0).
    SET ch to TERMINAL:INPUT:getchar().
    IF ch = TERMINAL:INPUT:RETURN {
        //PRINT "You Typed " +INPUT_STRING.
        parse_command(INPUT_STRING).
        SET OLD_INPUT_STRING TO INPUT_STRING.
        SET INPUT_STRING TO "".
    } ELSE IF ch = terminal:input:UPCURSORONE {
        //CLEARSCREEN.
        SET INPUT_STRING TO OLD_INPUT_STRING.
    } ELSE IF ch = terminal:input:BACKSPACE {
        //CLEARSCREEN.
        IF (INPUT_STRING:LENGTH > 0) {
            SET INPUT_STRING TO INPUT_STRING:REMOVE(INPUT_STRING:LENGTH-1 ,1).
        }
    } ELSE {
        //CLEARSCREEN.
        SET INPUT_STRING TO INPUT_STRING+ch.
    }
}

// TX SECTION END
