
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


local PARAM is get_param(readJson("1:/param.json"), "UTIL_TERM", lexicon()).
local startup_command is get_param(PARAM, "STARTUP_COMMAND","").

local lock H to terminal:height.
local lock W to terminal:width.

local function util_term_get_help_str {
    return list(
        core:tag + " terminal",
        ship:name,
        "command syntax:",
        "...",
        "help        help page 0",
        "help tags   list modules",
        "help [tag]  module help",
        "comm        run command",
        "comm(1,2)   run with args",
        "comm str    arg is str",
        "com1;com2   chain commands",
        "rst         reboot all cpus",
        "run [file]  of commands from base",
        "neu         neutralize controls",
        "K       single char is same key"
        ).
}

local function print_help_page {
    parameter help_str.
    local page_size is terminal:height-2.
    local char_in is -1.
    local offset is 0.
    local prespacer is "  ".

    local dis_str is list().
    local twidth is terminal:width-prespacer:length.

    for oneline in help_str {
        local hline is oneline.
        local nhline is ceiling(hline:length/twidth).
        for i in range(0,nhline) {
            dis_str:add(hline:substring(0,min(hline:length,twidth))).
            set hline to hline:remove(0,min(hline:length,twidth)).
        }
    }
    if dis_str:length > page_size {
        // do a scrolling print if help will not fit screen                
        until false {
            CLEARSCREEN.
            print_help_page(dis_str:sublist(offset,page_size)).
            if offset = dis_str:length-page_size {
                print "---q/"+char(8629)+"---".
            } else {
                print "---" +char(8593)+"/"++char(8595)+"---".
            }
            set char_in to TERMINAL:INPUT:getchar().
            
            if char_in = terminal:input:UPCURSORONE {
                set offset to max(0,offset-1).
            } else if char_in = terminal:input:DOWNCURSORONE {
                set offset to min(dis_str:length-page_size,offset+1).
            } else if char_in = terminal:input:ENTER or char_in = "q" {
                break.
            }
        }
    } else {
        local i is dis_str:iterator.
        until not i:next {
            print prespacer + i:value.
        }
    }
}

local function do_action_group_or_key {
    parameter key_in.
    // try sending the message to shsys regardless whether it's enabled
    if defined UTIL_SHBUS_ENABLED {
        util_shbus_tx_msg("SYS_DO_ACTION", key_in).
        return true.
    }
    return false.
}

// util_term_parse_command function is named like a global function
// it should serve as a template for other utilities' parse_command functions
local function util_term_parse_command {
    parameter commtext.
    parameter args is -1.

    if commtext:startswith("help") {
        local tags is list("TERM").
        if commtext = "help" or commtext:contains("TERM") {
            print_help_page(util_term_get_help_str()).
        } else if defined UTIL_SHBUS_ENABLED and (tags:add("SHBUS") = 0) and commtext:contains("SHBUS") {
            print_help_page(util_shbus_get_help_str()).
        } else if defined UTIL_FLDR_ENABLED and (tags:add("FLDR") = 0) and commtext:contains("FLDR") {
            print_help_page(util_fldr_get_help_str()).
        } else if defined UTIL_WP_ENABLED and (tags:add("WP") = 0) and commtext:contains("WP") {
            print_help_page(util_wp_get_help_str()).
        } else if defined UTIL_HUD_ENABLED and (tags:add("HUD") = 0) and commtext:contains("HUD") {
            print_help_page(util_hud_get_help_str()).
        } else if defined UTIL_RADAR_ENABLED and (tags:add("RADAR") = 0) and commtext:contains("RADAR") {
            print_help_page(util_radar_get_help_str()).
        } else if defined UTIL_DEV_ENABLED and (tags:add("DEV") = 0) and commtext:contains("DEV") {
            print_help_page(util_dev_get_help_str()).
        } else if commtext:contains("tags") {
            print "Available modules".
            print_help_page(tags).
        } else {
            print "usage: help [tag]".
        }
    } else if commtext:length = 1 and do_action_group_or_key(commtext){
        print("key "+commtext).
    } else if commtext:startswith("neu"){
        set ship:control:neutralize to true.
    } else if commtext:startswith("rst"){
        list PROCESSORS in cpus.
        for cpu in cpus {
            if not (cpu:tag = core:tag) {
                cpu:deactivate().
                wait 0.1.
                cpu:activate().
            }
        }
        print "waiting before reestablishing comms".
        wait 1.5.
        if (defined UTIL_SHBUS_ENABLED) and UTIL_SHBUS_ENABLED {
            wait 0.1.
            util_shbus_reconnect().
        }
    } else if commtext:startswith("run") {
        local runfile is commtext:replace("run",""):trim().
        if HOMECONNECTION:ISCONNECTED and exists("0:/term-scripts/"+runfile) {
            local filecontent is open("0:/term-scripts/"+runfile):readall.
            local i is filecontent:iterator.
            until not i:next {
                print i:value:split("#")[0].
                util_term_do_command(i:value:split("#")[0]).
            }
        } else {
            print "0:/term-scripts/"+runfile+"does not exist".
        }
    } else {
        return false.
    }
    return true.
}

// separates elements in parentheses from text portion of a command
//  "arg text(1,2,tag,3)ignored" -> list("arg text", list(1,2,"tag",3))
local function raw_input_to_args {
    // will return a list of numbers, a list of strings or -1 (no args in command)
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
            local arg_as_num is i:toscalar(-9999999).
            if arg_as_num = -9999999 {
                numlist:add(i:trim()).
            } else {
                numlist:add(arg_as_num).
            }
        }
        print commtext:substring(0,arg_start).
        print numlist.
        return list(commtext:substring(0,arg_start),numlist).
    }
    return list(commtext,-1).
}


local function parse_command {
    parameter commtextfull.
    if commtextfull = "" {
        return true.
    }

    for comm in commtextfull:split(";") {

        local parsed is raw_input_to_args(comm:trim()).
        local commtext is parsed[0].
        local args is parsed[1].

        if util_term_parse_command(commtext,args) {
           print("terminal parsed").
        } else if defined UTIL_SHBUS_ENABLED and util_shbus_parse_command(commtext,args) {
           print("shbus parsed").
        } else if defined UTIL_FLDR_ENABLED and util_fldr_parse_command(commtext,args) {
            print("fldr parsed").
        } else if defined UTIL_WP_ENABLED and util_wp_parse_command(commtext,args) {
            print("wp parsed").
        } else if defined UTIL_HUD_ENABLED and util_hud_parse_command(commtext,args) {
            print("hud parsed").
        } else if defined UTIL_RADAR_ENABLED and util_radar_parse_command(commtext,args) {
            print("radar parsed").
        //} else if util_dev_parse_command(commtext,args) {
        //  print "dev parsed".
        } else {
            print("Could not parse command("+ commtext:length + "):" + commtext).
            return false.
        }
    }
    wait 0.1.
    wait 0.1.
    if (defined UTIL_SHBUS_ENABLED) and UTIL_SHBUS_ENABLED {
        until not util_shbus_rx_msg() {}
    }
    return true.
}

local lock COMM_STRING to core:tag:tolower()+"@"+string_acro(ship:name)+":~$".
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
    parse_command(comm_string_input).   
}

function util_term_do_startup {
    util_term_do_command(startup_command).
}

// TX SECTION END
