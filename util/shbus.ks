
// This file manages communication betweeen processors in a ship and other ships

// Messages that are transmitted between shbuses are of the following format
// MSG:content -> list( FULLNAME, OPCODE, list(data0,data1,...,dataN))

// Utilities can have their own message receiving functions called by this file
// and they should follow the form of util_shbus_decode_rx_msg() i.e.
//  util_dev_decode_rx_msg(MSG) -> true if this function decoded
GLOBAL UTIL_SHBUS_ENABLED IS true.

// TX SECTION

local PARAM is readJson("1:/param.json")["UTIL_SHBUS"].

local tx_hosts is lexicon().
local single_host_key is "".
local exclude_host_key is "".

// objects in tx_hosts are saved using a SINGLENAME
// SINGLENAME can be
//  ship:name  (for other ships)
//  cpu:tag    (for cores on current ship)

// messages are sent with the FULLNAME of the sender,
// which can be used to route a message
// a FULLNAME is 
// ship:name+SEP+core:tag for a particular ship, core combination

local SEP is char(10).
local lock my_fullname to ship:name+SEP+core:tag.

// terminal compatible functions
function util_shbus_get_help_str {
    return list(
        " ",
        "UTIL_SHBUS  running on "+core:tag,
        "askhost ARG ask to send msgs",
        "unask   ARG stop send msgs",
        "listhosts   list saved hosts",
        "onehost ARG toggle only send to ",
        "exchost ARG toggle exclude this ",
        "hello       hello to hosts",
        "flush       clear message queues",
        "inv         invalid message",
        " ARG=[cpu tag on ship] or",
        " ARG=target            or",
        " ARG=result from listhosts"
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
            local new_host is 0.
            if args:startswith("target"){
                if HASTARGET {
                    if (ship:name = TARGET:name) { print "warning adding self".}
                    set new_host to TARGET.
                    set new_host_name to TARGET:name.
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
            if not (new_host_name = -1) {
                tx_hosts:add(new_host_name, new_host).
                util_shbus_tx_msg("ASKHOST", list(), list(new_host_name)).
            }
        }
    } else if commtext:STARTSWITH("listhosts") {
        local i is 0.
        for key in tx_hosts:keys {

            print ""+i + (choose " (X) " if (key = exclude_host_key) else 
                (choose " (*) " if (key = single_host_key) else " ") ) + key.
            set i to i+1.
        }
    } else if commtext:startswith("onehost") {
        if single_host_key = "" {
            if brackets { set args to tx_hosts:keys[args[0]].}
            // hoping order of returned keys does not vary
            if (tx_hosts:haskey(args)) {
                set single_host_key to args.
            }
        } else {
            set single_host_key to "".
        }
    } else if commtext:startswith("exchost") {
        if exclude_host_key = "" {
            if brackets { set args to tx_hosts:keys[args[0]].}
            if (tx_hosts:haskey(args)) {
                set exclude_host_key to args.
            }
        } else {
            set exclude_host_key to "".
        }
    } else if commtext:STARTSWITH("unask") {
        if args = -1 {
            print "unask expected string arg".
        } else {
            if brackets { set args to tx_hosts:keys[args[0]].}
            if (tx_hosts:haskey(args)) {
                util_shbus_tx_msg("UNASKHOST", list(), list(args)).
                tx_hosts:remove(args).
            } else {
                print "did not find host " + args.
            }
        }
    } else if commtext:STARTSWITH("flush"){
        until not util_shbus_rx_msg() { }
    } else if commtext:STARTSWITH("inv"){
        util_shbus_tx_msg("a;lsfkja;wef",list(13,4,5)).
    } else {
        return false. // could not parse command
    }
    return true.
}

function util_shbus_tx_msg {
    parameter opcode_in.
    parameter data_in is LIST().
    parameter recipients is tx_hosts:keys. // is always a list of keys

    if not (single_host_key = "") {
        set recipients to list(single_host_key).
    }
   
    for key in recipients {
        if tx_hosts:haskey(key) and not (key = exclude_host_key){
            if not tx_hosts[key]:connection:sendmessage(list(my_fullname,opcode_in,data_in)) {
                print "could not send message:" + opcode_in +
                    char(10) +"   "+ data_in +
                    char(10) +"to "+ host.
            }
        }
    }
}

function util_shbus_reconnect {
    for key in tx_hosts:keys {
        util_shbus_tx_msg("ASKHOST", list(), list(key)).       
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

local function get_single_name {
    parameter fullname_in.
    // local ship_name_in is fullname_in:split(SEP)[0].
    // local cpu_name_in is fullname_in:split(SEP)[1].
    if not fullname_in:contains(SEP) {
        print "inavlid use of get_single_name".
        print "on " + ship:name + " " + core:tag + " with " + fullname_in.
        // print error_causing_undefined_variable.
        return fullname_in.
    }
    if (ship:name = fullname_in:split(SEP)[0]){
        return fullname_in:split(SEP)[1]. // return core
    } else {
        return fullname_in:split(SEP)[0]. // return other ship
    }
}

// RX SECTION

// send back ack ack ack ack ack ack ack
function util_shbus_ack{
    parameter ack_str.
    parameter sender. // is always a fullname
    // data is [fullname of who ack is for, fullname of who is acking, ack_content]

    util_shbus_tx_msg("ACK", list(sender, my_fullname, ack_str), list(get_single_name(sender))).
}

// this function serves as a template for other receiving messages
//  notice that args are similar to those for tx_msg.
//   difference is a message being sent can have multiple recipients
//   but a message received has only one sender
local function util_shbus_decode_rx_msg {
    parameter sender. // is always a fullname
    parameter opcode.
    parameter data.

    local sender_single_name is get_single_name(sender).

    if opcode = "HELLO" {
        print "" + sender + "says hello!".
        util_shbus_ack("hey!", sender).
    } else if opcode = "ACK" {
        if my_fullname = data[0] {
            print data[1] +" acked:".
            print data[2].
        } else if data[0]:startswith(ship:name) {
            // ACK wasn't for me, try forwarding it to one of my cpus
            // it is expected that ship is matched but I'm just making sure
            util_shbus_tx_msg("ACK", data, list(get_single_name(data[0]))).
        } else {
            print "Received an ACK that was not for me".
        }
    } else if opcode = "ASKHOST" {
        if not tx_hosts:haskey(sender_single_name) {
            local new_host is find_cpu(sender_single_name).
            if new_host = -1 { set new_host to find_ship(sender_single_name).}
            // search for target of this name if no CPU of this name is found
            if not (new_host = -1) {
                tx_hosts:add(sender_single_name, new_host).
                print "added rx host " + sender_single_name+ " "+new_host:name.
            }
        }
    } else if opcode = "UNASKHOST" {
        if tx_hosts:haskey(sender_single_name) {
            print "removing rx host " + sender_single_name + " " + tx_hosts[sender_single_name]:name.
            tx_hosts:remove(sender_single_name).
        }
    } else {
        return false.
    }
    return true.
}

// check for any new messages and run any commands immediately
// do not return any value
function util_shbus_rx_msg {
    local received_msg is 0.

    if not core:messages:empty or not ship:messages:empty{
        if not core:messages:empty {
            set received_msg to core:messages:pop.
        } else if not ship:messages:empty {
            set received_msg to ship:messages:pop.
        }

        local sender is received_msg:content[0]. // string
        local opcode is received_msg:content[1]. // string
        local data is received_msg:content[2]. // list of args

        if util_shbus_decode_rx_msg(sender, opcode, data) {
            print "shbus decoded".
        } else if UTIL_WP_ENABLED and util_wp_decode_rx_msg(sender, opcode, data) {
            print "wp decoded.".
        } else if UTIL_FLDR_ENABLED and util_fldr_decode_rx_msg(sender, opcode, data) {
            print "fldr decoded".
        } else if UTIL_SHSYS_ENABLED and util_shsys_decode_rx_msg(sender, opcode, data) {
            print "shsys decoded".
        } else if UTIL_HUD_ENABLED and util_hud_decode_rx_msg(sender, opcode, data) {
            print "hud decoded".
        } else {
            print "Unexpected message from "+received_msg:SENDER:NAME +
            "("+ received_msg:SENDER+"): " + received_msg:CONTENT.
        }
        return true.
    } else {
        return false.
    }
}

// RX SECTION END
