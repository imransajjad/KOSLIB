
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_FLDR_ENABLED) { GLOBAL UTIL_FLDR_ENABLED IS false.}
GLOBAL UTIL_SHBUS_TX_ENABLED IS true.

// TX SECTION

// SET FLCS_PROC TO 0. required global.

local lock H to terminal:height.
local lock W to terminal:width.

global HELP_LIST is LIST(
" ",
"SHBUS_TX running on "+core:tag,
"run a command using the following syntax",
"...",
"help.  help page 0.",
"help(n).  help page n.",
"command.",
"command_with_num_args(1,2,3).",
"command_with_str_arg string.",
"chained_command_1.chained_command_2(3,2,1).",
"hello.  send hello to flcs.",
"inv.  invalid message.").

if UTIL_FLDR_ENABLED {
    local newlist is util_wp_get_help_str().
    for i in range(0,newlist:length) {
        HELP_LIST:add(newlist[i]).
    }

}
if UTIL_WP_ENABLED {
    local newlist is util_fldr_get_help_str().
    for i in range(0,newlist:length) {
        HELP_LIST:add(newlist[i]).
    }
}

local function print_help_page {
    parameter page.
    local page_size is 12.

    for i in range(page_size*page, page_size*(page+1)+2 ) {
        if i < HELP_LIST:length {
            print "  "+HELP_LIST[i].
        }
    }
}

local function print_help_by_tag {
    parameter tag.
    local do_print is false.
    for i in range(0,HELP_LIST:length) {
        if HELP_LIST[i]:startswith(tag) { set do_print to true.}
        if HELP_LIST[i]:startswith(" ") { set do_print to false.}
        if do_print {
            print HELP_LIST[i].
        }
    }
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
        if commtext:contains(" ") {
            print_help_by_tag( (commtext:split(" ")[1]):replace(".", "") ).
        } else if commtext:length > 5 {
            print_help_page(util_shbus_raw_input_to_args(commtext)[0]).
        } else {
            print_help_page(0).
        }
    } else if commtext:STARTSWITH("inv."){
        util_shbus_tx_msg("a;lsfkja;wef",list(13,4,5)).
    } else if UTIL_FLDR_ENABLED and util_fldr_parse_command(commtext) {
        print("fldr parsed").
    } else if UTIL_WP_ENABLED and util_wp_parse_command(commtext) {
        print("wp parsed").
    //} else if util_dev_parse_command(commtext) {
    //  print "dev parsed".
    } else {
        print("Could not parse command.").
        return false.
    }
    return parse_command(commtextnext).
}

function util_shbus_tx_msg {
    PARAMETER opcode_in, data_in is LIST(0).
    IF NOT FLCS_PROC:CONNECTION:SENDMESSAGE(LIST(opcode_in,data_in)) {
        print("could not send message "+ arg_in).
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

local COMM_STRING is core:tag+":~$".
local INPUT_STRING is "".
local OLD_INPUT_STRING is "".

local lock str_length to COMM_STRING:length + INPUT_STRING:length.
local lock num_lines to 1+floor(str_length/W).
local current_line is H-1.
local max_lines is 1.

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
    print COMM_STRING+INPUT_STRING+PAD_STRING AT(0, the_line).

}

local function print_lowest_line_again {
    if (max_lines = num_lines) {
        local start is (num_lines-1)*W.
        print (COMM_STRING+INPUT_STRING):substring(start, str_length-start).
    }
}

CLEARSCREEN.
print_help_page(0).

function util_shbus_get_input {
    print_overflowed_line().


    SET ch to TERMINAL:INPUT:getchar().
    IF ch = TERMINAL:INPUT:RETURN {
        
        print_lowest_line_again().
        parse_command(INPUT_STRING).
        
        SET OLD_INPUT_STRING TO INPUT_STRING.
        SET INPUT_STRING TO "".
        set current_line to H-1.
        set max_lines to 1.
    } ELSE IF ch = terminal:input:UPCURSORONE {
        SET INPUT_STRING TO OLD_INPUT_STRING.
    } ELSE IF ch = terminal:input:BACKSPACE {
        IF (INPUT_STRING:LENGTH > 0) {
            SET INPUT_STRING TO INPUT_STRING:REMOVE(INPUT_STRING:LENGTH-1 ,1).
        }
    } ELSE {
        //CLEARSCREEN.
        SET INPUT_STRING TO INPUT_STRING+ch.
    }
}

// TX SECTION END
