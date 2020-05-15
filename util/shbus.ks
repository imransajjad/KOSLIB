
// This file manages communication betweeen processors in a ship and other ships

// Messages that are transmitted between shbuses are of the following format
// MSG:content -> list( SENDERNAME, OPCODE, list(data0,data1,...,dataN))

// Utilities can have their own message receiving functions called by this file
// and they should follow the form of util_shbus_decode_rx_msg() i.e.
//  util_dev_decode_rx_msg(MSG) -> true if this function decoded
GLOBAL UTIL_SHBUS_ENABLED IS true.

local forward_acks_upwards is false.

function util_shbus_forward_acks {
    parameter bool_in.
    set forward_acks_upwards to bool_in.
}

// TX SECTION

local PARAM is readJson("1:/param.json")["UTIL_SHBUS"].

local tx_hosts is lexicon().

local self_name is string_acro(ship:name)+core:tag.

// terminal compatible functions
function util_shbus_get_help_str {
    return list(
        " ",
        "UTIL_SHBUS  running on "+core:tag,
        "askhost ARG ask to send msgs and receive acks",
        "unask ARG   stop send msgs and receive acks",
        "listhosts   list saved hosts",
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
            if args:startswith("target"){
                if HASTARGET {
                    local new_host_name is TARGET:name.
                    tx_hosts:add(new_host_name, TARGET).
                    util_shbus_tx_msg("ASKHOST", list(ship:name), list(new_host_name)).
                } else {
                    print "askhost could not find target".
                }
            } else {
                if tx_hosts:haskey(args) {
                    print "already have a host with this name".
                } else {
                    local new_host is find_cpu(args).
                    if not (new_host = -1) {
                        tx_hosts:add(args,new_host).
                        util_shbus_tx_msg("ASKHOST", list(core:tag), list(args) ).
                    }
                }
            }
        }
    } else if commtext:STARTSWITH("listhosts") {
        print tx_hosts:keys.
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
    parameter recipients is tx_hosts:keys.
   
    for key in recipients {
        if tx_hosts:haskey(key) {
            if not tx_hosts[key]:connection:sendmessage(list(self_name,opcode_in,data_in)) {
                print "could not send message:" + opcode_in +
                    char(10) +"   "+ data_in +
                    char(10) +"to "+ host.
            }
        }
    }
}

function util_shbus_reconnect {
    for key in tx_hosts:keys {
        local new_host is find_cpu(key).
        if not (new_host = -1) {
            util_shbus_tx_msg("ASKHOST", list(core:tag), list(key) ).
        } else {
            set new_host to find_ship(key).
            if not (new_host = -1) {
                util_shbus_tx_msg("ASKHOST", list(ship:name), list(key) ).
            }
        }
        
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

// RX SECTION

// this function serves as a template for other receiving messages
//  notice that args are similar to those for tx_msg.
//   difference is a message being sent can have multiple recipients
//   but a message received has only one sender
local function util_shbus_decode_rx_msg {
    parameter sender.
    parameter opcode.
    parameter data.

    if opcode = "HELLO" {
        print "" + sender + "says hello!".
        util_shbus_tx_msg("ACK", list("hey!"), list(sender)).
    } else if opcode = "ACK" {
        if forward_acks_upwards {
            for host_key in tx_hosts:keys {
                if not (find_cpu(host_key) = -1) {
                    set data[0] to sender+ "acked: "+char(10)+data[0].
                    util_shbus_tx_msg("ACK", data, list(tx_hosts[host_key])).
                    return true. // send to first on ship cpu in tx_hosts
                    // will need to think about this more
                }
            }

        } else {
            print sender +" acked:".
            for i in data {
                print i.
            }
        }
    } else if opcode = "ASKHOST" {
        if not tx_hosts:haskey(sender) {
            local new_host is find_cpu(data[0]).
            if new_host = -1 { set new_host to find_ship(data[0]).}
            // search for target of this name if no CPU of this name is found
            if not (new_host = -1) {
                tx_hosts:add(sender, new_host).
                print "added rx host " + sender+ " "+tx_hosts[sender]:name.
            }
        }
    } else if opcode = "UNASKHOST" {
        if tx_hosts:haskey(sender) {
            print "removing rx host " + sender + " " + tx_hosts[sender]:name.
            tx_hosts:remove(sender).
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
