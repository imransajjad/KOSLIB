
// This Utility takes text input from the terminal and does commmands
// There are some native commands and other utilities can also provide
// additional commands.

// The terminal tries to parse a command. Native commands are tried first
// Then every command registered with the terminal utility is tried. If input
// string does not match any loaded command type, an error message is displayed.

// a utility providing additional commands shall have a function like this
//  util_dev_parse_command( commtext, list_of_args ) -> true if command valid
//    commtext = "dev_go_to_orbit(75000,0.0)", list_of_args = list(75000,0.0)
//    commtext = "dev_name_orbit LKO", list_of_args = "LKO"
//   commtext is the full command, list_of_args is a list of numbers or a string

GLOBAL UTIL_TERM_ENABLED IS true.

// TX SECTION


local PARAM is readJson("1:/param.json").

local lock H to terminal:height.
local lock W to terminal:width.

local HELP_LIST is LIST(
" ",
core:tag + " terminal",
ship:name,
"command syntax:",
"...",
"help        help page 0",
"help(n)     help page n",
"comm        run command",
"comm(1,2)   run with args",
"comm str    arg is str",
"com1;com2   chain commands",
"rst         reboot all cpus",
"neu         neutralize controls",
"K       single char is same key"
).

local HELP_LIST_UPDATED is false.
local function update_help_list {
    if HELP_LIST_UPDATED {
        return.
    }
    if (defined UTIL_SHBUS_ENABLED) and UTIL_SHBUS_ENABLED {
        local newlist is util_shbus_get_help_str().
        for i in range(0,newlist:length) {
            HELP_LIST:add(newlist[i]).
        }
        set HELP_LIST_UPDATED to true.
    }
    if (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED {
        local newlist is util_wp_get_help_str().
        for i in range(0,newlist:length) {
            HELP_LIST:add(newlist[i]).
        }
        set HELP_LIST_UPDATED to true.
    }
    if (defined UTIL_FLDR_ENABLED) and UTIL_FLDR_ENABLED {
        local newlist is util_fldr_get_help_str().
        for i in range(0,newlist:length) {
            HELP_LIST:add(newlist[i]).
        }
        set HELP_LIST_UPDATED to true.
    }
    if (defined UTIL_HUD_ENABLED) and UTIL_HUD_ENABLED {
        local newlist is util_hud_get_help_str().
        for i in range(0,newlist:length) {
            HELP_LIST:add(newlist[i]).
        }
        set HELP_LIST_UPDATED to true.
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
    update_help_list().
    print_help_page_by_index(page_size*page).
}

local function print_help_by_tag {
    parameter tag.
    update_help_list().
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

// util_term_parse_command function is named like a global function
// it should serve as a template for other utilities' parse_command functions
local function util_term_parse_command {
    parameter commtext.
    parameter args is list().

    if commtext:STARTSWITH("help") {
        if commtext:contains(" ") {
            print_help_by_tag( (commtext:split(" ")[1]):replace(".", "") ).
        } else if commtext:length > 5 {
            print_help_page(args[0]).
        } else {
            print_help_page(0).
        }
    } else if commtext:length = 1 and do_action_group_or_key(commtext){
        print("key "+commtext).
    } else if commtext:STARTSWITH("neu"){
        set ship:control:neutralize to true.
    } else if commtext:STARTSWITH("rst"){
        list PROCESSORS in cpus.
        for cpu in cpus {
            if not (cpu:tag = core:tag) {
                cpu:deactivate().
                wait 0.1.
                cpu:activate().
            }
        }
    } else {
        return false.
    }
    return true.
}

// get list of numbers or strings or -1 from commtext
local function raw_input_to_args {
    // will return a list of numbers, a string or -1 (no args in command)
    parameter commtext.
    if commtext:contains("(") AND commtext:contains(")") {
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
    if commtext:split(" "):length > 1 {
        local n is commtext:find(" ")+1.
        return commtext:substring(n,commtext:length-n).

    }
    return -1.
}


local function parse_command {
    parameter commtextfull.
    if commtextfull = "" {
        return true.
    }

    for comm in commtextfull:split(";") {

        local commtext is comm:trim().
        local args is raw_input_to_args(commtext).

        if util_term_parse_command(commtext,args) {
           print("terminal parsed").
        } else if (defined UTIL_SHBUS_ENABLED) and UTIL_SHBUS_ENABLED and util_shbus_parse_command(commtext,args) {
           print("shbus parsed").
        } else if (defined UTIL_FLDR_ENABLED) and UTIL_FLDR_ENABLED and util_fldr_parse_command(commtext,args) {
            print("fldr parsed").
        } else if (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED and util_wp_parse_command(commtext,args) {
            print("wp parsed").
        } else if (defined UTIL_HUD_ENABLED) and UTIL_HUD_ENABLED and util_hud_parse_command(commtext,args) {
            print("hud parsed").
        //} else if util_dev_parse_command(commtext,args) {
        //  print "dev parsed".
        } else {
            print("Could not parse command("+ commtext:length + "):" + commtext).
            return false.
        }
    }
    wait(0.1).
    wait(0.1).
    util_shbus_rx_msg().
    return true.
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

function util_term_get_input {
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


function util_term_do_command {
    parameter comm_string_input is "".

    if comm_string_input = "" {
        print "util_shbus_tx_do_command invalid param".
    } else {
        parse_command(comm_string_input).
    }
}

// TX SECTION END
