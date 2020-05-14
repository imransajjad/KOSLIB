
// This file manages communication betweeen processors in a ship and other ships

// Messages that are transmitted between shbuses are of the following format
// MSG:content -> list( OPCODE, list(data0,data1,...,dataN))

// Utilities can have their own message receiving functions called by this file
// and they should follow the form of util_shbus_decode_rx_msg() i.e.
//  util_dev_decode_rx_msg(MSG) -> true if this function decoded
GLOBAL UTIL_SHBUS_ENABLED IS true.

local host_enabled is false.
local hostproc is "".

// TX SECTION

local PARAM is readJson("1:/param.json")["UTIL_SHBUS"].
local FLCS_PROC is (choose PROCESSOR(PARAM["FLCS_PROC_TAG"]) if PARAM:haskey("FLCS_PROC_TAG") else 0).

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
        "hello       hello to flcs",
        "inv         invalid message",
        " ARG=[cpu tag on ship] or",
        " ARG=target            or",
        " ARG=[result from listhosts"
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
                    set new_host_name to TARGET:name.
                    tx_hosts:add(new_host_name, TARGET).
                    util_shbus_tx_msg("ASKHOST", list(self_name,ship:name), list(new_host_name)).
                } else {
                    print "askhost could not find target".
                }
            } else {
                if tx_hosts:haskey(args) {
                    print "already have a host with this name".
                } else {
                    list processors in plist.
                    for p in plist {
                        if p:tag = args {
                            tx_hosts:add(args,p).
                            util_shbus_tx_msg("ASKHOST", list(self_name,core:tag), list(args) ).
                        }
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
                util_shbus_tx_msg("UNASKHOST", list(self_name), list(args)).
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
    PARAMETER opcode_in.
    parameter data_in is LIST().
    parameter tx_host_which_keys is tx_hosts:keys.
   
    for key in tx_host_which_keys {
        if not tx_hosts[key]:connection:sendmessage(list(opcode_in,data_in)) {
            print "could not send message:" + opcode_in +
                char(10) +"   "+ data_in +
                char(10) +"to "+ host.
        }
    }
}

// TX SECTION END


// RX SECTION

// We need this function because tx_msg(ship) does not work
// The receiving end probably receives a serialized copy which has
// nothing to do with the ship or target
local function find_cpu_or_ship {
    parameter tag.
    list processors in P.
    for p in P {
        if p:tag = tag { return p.}
    }

    list targets in target_list.
    local i is target_list:iterator.
    until not i:next {
        if (i:value:name = tag) { return i:value.}
    }
    return -1.
}


// this function serves as a template for other receiving messages
local function util_shbus_decode_rx_msg {
    parameter msg.

    if msg:content[0] = "HELLO" {
        print "" + msg:sender + "says hello!".
        util_shbus_tx_msg("ACK", list("hey!")).
    } else if msg:content[0] = "ACK" {
        for i in msg:content[1] {
            print i.
        }
    } else if msg:content[0] = "ASKHOST" {
        if not tx_hosts:haskey(msg:content[1][0]) {
            local new_host is find_cpu_or_ship(msg:content[1][1]).
            if not (new_host = -1) {
                tx_hosts:add(msg:content[1][0], new_host).
                print "added rx host " + msg:content[1][0]+ " "+tx_hosts[msg:content[1][0]]:name.
            }
        }
    } else if msg:content[0] = "UNASKHOST" {
        if tx_hosts:haskey(msg:content[1][0]) {
            print "removing rx host " + msg:content[1][0]+ " "+tx_hosts[msg:content[1][0]]:name.
            tx_hosts:remove(msg:content[1][0]).
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

        if util_shbus_decode_rx_msg(received_msg) {
            print "shbus decoded".
        } else if UTIL_WP_ENABLED and util_wp_decode_rx_msg(received_msg) {
            print "wp decoded.".
        } else if UTIL_FLDR_ENABLED and util_fldr_decode_rx_msg(received_msg) {
            print "fldr decoded".
        } else if UTIL_SHSYS_ENABLED and util_shsys_decode_rx_msg(received_msg) {
            print "shsys decoded".
        } else if UTIL_HUD_ENABLED and util_hud_decode_rx_msg(received_msg) {
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
