
// This file manages communication betweeen processors in a ship and other ships

// Messages that are transmitted between shbuses are of the following format
// MSG:content -> list( SENDER, RECIPIENT, OPCODE, list(data0,data1,...,dataN))

// Utilities can have their own message receiving functions called by this file
// and they should follow the form of util_shbus_decode_rx_msg() i.e.
//  util_dev_decode_rx_msg(MSG) -> true if this function decoded
GLOBAL UTIL_SHBUS_ENABLED IS true.

// TX SECTION

local PARAM is get_param(readJson("param.json"),"UTIL_SHBUS", lexicon()).
local SHIP_ROUTER_CORE is (get_param(PARAM, "ship_router_core_tag", "flcs") = core:tag).
local RX_MSG_IN_TRIGGER is get_param(PARAM, "RX_MSG_IN_TRIGGER", false).
print "shbus rx msg in interrupt:" + RX_MSG_IN_TRIGGER.

local tx_hosts is lexicon().
local single_host_key is "".
local exclude_host_key is "".

// objects in tx_hosts are saved using a NAME and can be
//  ship:name  (for other ships)
//  cpu:tag    (for cores on current ship)
//  ship:name+SEP+cpu:tag    (for cores on other ship)

local SEP is "+".
local lock my_fullname to ship:name+SEP+core:tag.

local function print_hosts {
    local i is 0.
    for key in tx_hosts:keys {

        print ""+i + (choose " (X) " if (key = exclude_host_key) else 
            (choose " (*) " if (key = single_host_key) else " ") ) + key.
        set i to i+1.
    }
}

// terminal compatible functions
function util_shbus_get_help_str {
    return list(
        "UTIL_SHBUS  running on "+core:tag,
        "askhost ARG ask to send msgs",
        "unask   ARG stop send msgs",
        "listhosts   list saved hosts",
        "hosttags    get tags from hosts",
        "onlyhost ARG toggle only send to (no ARG resets)",
        "exclhost ARG toggle exclude this (no ARG resets)",
        "hello       hello to hosts",
        "inv         invalid message",
        "shtx(OP,DATA)  custom command",
        " ARG=[core]            or",
        " ARG=target            or",
        " ARG=target [core]     or",
        " ARG=(index) from listhosts",
        "This utlility is a way to setup communication between utilities running on other cores or ships.",
        "Usual flow is askhost -> onlyhost(3) -> gettags -> do other commands -> unaskhost. For example, WP messages are sent by this utility and SHBUS on the receiving end dispatches them to WP."
        ).
}

function util_shbus_parse_command {
    parameter commtext.
    parameter args is -1.

    local brackets is false.
    if commtext:contains("(") {
        set brackets to true.        
    }

    if commtext:STARTSWITH("hello") {
        util_shbus_tx_msg("hello").
    } else if commtext:STARTSWITH("askhost") {
        if args = -1 or brackets {
            print "askhost expected string arg".
        } else {
            local new_host_name is -1.
            local new_host is -1.
            local splitargs is args:split(" ").
            if splitargs[0] = "target" {
                if ISACTIVEVESSEL and HASTARGET {
                    if (ship:name = TARGET:name) { print "warning adding self".}
                    set new_host to TARGET.
                    splitargs:remove(0).
                    set new_host_name to TARGET:name +
                    (choose SEP+splitargs:join(" ") if (splitargs:length >= 1) else "").
                } else {
                    print "askhost could not find target".
                }
            } else {
                if tx_hosts:haskey(args) {
                    print "already have a host with this name".
                } else if (args = core:tag) {
                    print "cannot add self".
                } else {
                    set new_host to find_cpu(args).
                    set new_host_name to args.
                }
            }
            if not (new_host = -1) and not tx_hosts:haskey(new_host_name){
                tx_hosts:add(new_host_name, new_host).
                util_shbus_tx_msg("ASKHOST", list(my_fullname), list(new_host_name)).
            }
        }
    } else if commtext:STARTSWITH("hosttags") {
        util_shbus_tx_msg("HOSTTAGS").
    } else if commtext:STARTSWITH("listhosts") {
        print_hosts().
    } else if commtext:startswith("onlyhost") {
        if args = -1 {
            set single_host_key to "".
        } else {
            if brackets and (args[0] < tx_hosts:keys:length) {
                set args to tx_hosts:keys[args[0]].
            }
            // hoping order of returned keys does not vary
            if (tx_hosts:haskey(args)) {
                set single_host_key to args.
            }
        }
        print_hosts().
    } else if commtext:startswith("exclhost") {
        if args = -1 {
            print "removing exclhost".
            set exclude_host_key to "".
        }
        else {
            if brackets and (args[0] < tx_hosts:keys:length) {
                set args to tx_hosts:keys[args[0]].
            }
            if (tx_hosts:haskey(args)) {
                set exclude_host_key to args.
            }
        }
        print_hosts().
    } else if commtext:STARTSWITH("unask") {
        if args = -1 {
            print "unask expected string arg".
        } else {
            if brackets and (args[0] < tx_hosts:keys:length) {
                set args to tx_hosts:keys[args[0]].
            }
            if (tx_hosts:haskey(args)) and not (args = exclude_host_key) {
                util_shbus_tx_msg("UNASKHOST", list(my_fullname), list(args)).
                tx_hosts:remove(args).
                if single_host_key = args {
                    set single_host_key to "".
                }
            } else {
                print "did not find host " + args.
            }
        }
        print_hosts().
    } else if commtext:STARTSWITH("inv"){
        util_shbus_tx_msg("a;lsfkja;wef",list(13,4,5)).
    } else if commtext:STARTSWITH("shtx"){
        if brackets {
            util_shbus_tx_msg(args[0],args:sublist(1,args:length-1)).
        } else {
            print "use shtx(OP_CODE, DATA)".
        }

    } else {
        return false. // could not parse command
    }
    return true.
}

function util_shbus_tx_msg {
    parameter opcode.
    parameter data is LIST().
    parameter recipients is tx_hosts:keys. // is always a list of keys
    parameter sender is my_fullname.

    if not (single_host_key = "") {
        set recipients to list(single_host_key).
    }
   
    for key in recipients {
        if tx_hosts:haskey(key) and not (key = exclude_host_key){
            if not tx_hosts[key]:connection:sendmessage(list(sender,key,opcode,data)) {
                print sender +" could not send message:" +
                    char(10) +"   "+ opcode + " " + data +
                    char(10) +"to "+ key.
            }
        }
    }
}

function util_shbus_reconnect {
    local temp_a is single_host_key.
    local temp_b is exclude_host_key.
    set single_host_key to "".
    set exclude_host_key to "".
    for key in tx_hosts:keys {
        util_shbus_tx_msg("ASKHOST", list(my_fullname), list(key)).       
    }
    set single_host_key to temp_a.
    set exclude_host_key to temp_b.
}

function util_shbus_disconnect {
    for key in tx_hosts:keys {
        util_shbus_tx_msg("UNASKHOST", list(my_fullname), list(key)).
        tx_hosts:remove(key).
    }
}

// TX SECTION END


// We need these functions because tx_msg(ship) does not work
// The receiving end probably receives a serialized copy which has
// nothing to do with the ship or target
local function find_cpu {
    parameter tag.
    list processors in ALL_PROCESSORS.
    for p in ALL_PROCESSORS {
        if p:tag = tag {
            return p.
        }
    }
    return -1.
}

local function find_ship {
    parameter tag.
    list targets in target_list.
    local i is target_list:iterator.
    until not i:next {
        if (i:value:name = tag) { return i:value.}
    }
    return -1.
}

local function get_final_name {
    parameter name_in.
    if not name_in:contains(SEP) {
        return name_in.
    } else {
        return name_in:split(SEP)[1].
    }
}

local function get_ship_name {
    parameter name_in.
    if not name_in:contains(SEP) {
        return -1.
    } else {
        return name_in:split(SEP)[0].
    }
}

// returns a savable hostname from fullname
local function resolve_name {
    parameter name_in. // is always ship:name+SEP+cpu:tag
    if name_in:contains(SEP) and ship:name = name_in:split(SEP)[0] {
        return name_in:split(SEP)[1].
        // return the core name
    }
    // we got ship:name+SEP+cpu:tag from another ship
    // do nothing
    return name_in.
}

// returns a host (not the name) from a fullname
local function resolve_obj {
    parameter name_in. // is always ship:name+SEP+cpu:tag
    local new_host is -1.
    if name_in:split(SEP)[0] = ship:name {
        // we got a core on our ship
        set new_host to find_cpu(name_in:split(SEP)[1]).
    } else {
        set new_host to find_ship(name_in:split(SEP)[0]).
    }
    return new_host.
}


// RX SECTION

// send back ack ack ack ack ack ack ack
function util_shbus_ack{
    parameter ack_str.
    parameter sender. // is always ship:name+SEP+cpu:tag
    // data is [fullname of who ack is for, fullname of who is acking, ack_content]
    util_shbus_tx_msg("ACK", list(sender, my_fullname, ack_str), list(resolve_name(sender))).
}

// this function serves as a template for other receiving messages
//  notice that args are similar to those for tx_msg.
//   difference is a message being sent can have multiple recipients
//   but a message received has only one sender
local function util_shbus_decode_rx_msg {
    parameter sender. // is always ship:name+SEP+cpu:tag
    parameter recipient.
    parameter opcode.
    parameter data.

    if opcode = "HELLO" {
        print "" + sender + " says hello!".
        util_shbus_ack("hey!", sender).
    } else if opcode = "ACK" {
        if my_fullname = data[0] {
            print data[1] +" acked:".
            print data[2].
        } else {
            print "Received an ACK that was not for me".
        }
    } else if opcode = "ASKHOST" {
        // data[0] is always a fullname
        local host_asking is resolve_name(data[0]).
        local new_host is resolve_obj(data[0]).
        if not tx_hosts:haskey(host_asking) and not (new_host = -1){
            tx_hosts:add(host_asking, new_host).
            print "added host " + host_asking+ "/"+ new_host:name.
        } else {
            print "could not add host " + host_asking.
        }
    } else if opcode = "UNASKHOST" {
        local host_asking is resolve_name(data[0]).
        if tx_hosts:haskey(host_asking) {
            print "removed host " + host_asking + "/" + tx_hosts[host_asking]:name.
            tx_hosts:remove(host_asking).
            if single_host_key = host_asking {
                set single_host_key to "".
            }
        } else {
            print "did not find " + host_asking.
        }
    } else if opcode = "HOSTTAGS" {
        local tags is list("SHBUS").
        if defined UTIL_TERM_ENABLED {tags:add("TERM").}
        if defined UTIL_FLDR_ENABLED {tags:add("FLDR").}
        if defined UTIL_WP_ENABLED {tags:add("WP").}
        if defined UTIL_HUD_ENABLED {tags:add("HUD").}
        if defined UTIL_RADAR_ENABLED {tags:add("RADAR").}
        if defined UTIL_DEV_ENABLED {tags:add("DEV").}
        util_shbus_ack("tags: " + char(10) + "  " + tags:join(char(10)+"  "), sender).
    } else {
        return false.
    }
    return true.
}

when RX_MSG_IN_TRIGGER then {
    rx_msg().
    return true. // make the trigger persist
}

// check for any new messages and run any commands immediately
// return whether a message was received
function util_shbus_rx_msg {
    if RX_MSG_IN_TRIGGER {
        // do nothing, interrupt will handle this
        return false. // did not "receive message" in this case
    } else {
        return rx_msg(). // call the local function directly
    }
}

local function rx_msg {
    local received_msg is 0.

    if not core:messages:empty or (SHIP_ROUTER_CORE and not ship:messages:empty){
        if not core:messages:empty {
            set received_msg to core:messages:pop.
        } else if SHIP_ROUTER_CORE and not ship:messages:empty {
            set received_msg to ship:messages:pop.
        }
        if not (received_msg:content:length = 4) {
            print "shbus_rx message not properly formatted".
            return true.
        }
        local sender is received_msg:content[0]. // string
        local recipient is received_msg:content[1]. // string
        local opcode is received_msg:content[2]. // string
        local data is received_msg:content[3]. // list of args

        if (get_final_name(recipient) = ship:name) or
                (recipient = core:tag) or (recipient = my_fullname) {
            // received message is for this ship or this ship+core

            if util_shbus_decode_rx_msg(sender, recipient, opcode, data) {
                print "shbus decoded".
            } else if defined UTIL_WP_ENABLED and util_wp_decode_rx_msg(sender, recipient, opcode, data) {
                print "wp decoded.".
            } else if defined UTIL_FLDR_ENABLED and util_fldr_decode_rx_msg(sender, recipient, opcode, data) {
                print "fldr decoded".
            } else if defined UTIL_SHSYS_ENABLED and util_shsys_decode_rx_msg(sender, recipient, opcode, data) {
                print "shsys decoded".
            } else if defined UTIL_HUD_ENABLED and util_hud_decode_rx_msg(sender, recipient, opcode, data) {
                print "hud decoded".
            } else {
                print "Unexpected message from "+received_msg:SENDER:NAME +
                "("+ received_msg:SENDER+"): " + received_msg:CONTENT.
            }
        } else if (get_ship_name(recipient) = ship:name) {
            // received message is for some other core on this ship
            util_shbus_tx_msg(opcode, data, list(get_final_name(recipient)), sender).
            // only sent if recipient in tx_hosts.
            print "routing msg to " + recipient.
        } else {
            print "msg not for my ship".
        }
        return true. // if a message was received
    } else {
        return false.
    }
}

function util_shbus_set_ship_router {
    parameter is_ship_router.
    set SHIP_ROUTER_CORE to is_ship_router.
}

// RX SECTION END
