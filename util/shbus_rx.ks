
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_FLDR_ENABLED) { GLOBAL UTIL_FLDR_ENABLED IS false.}
IF NOT (DEFINED UTIL_HUD_ENABLED) { GLOBAL UTIL_HUD_ENABLED IS false.}
GLOBAL UTIL_SHBUS_RX_ENABLED IS true.


// RX SECTION

local function print_message {
    parameter received_in.
    parameter float_print is false.
    print "MSG:" +received_in:content[0].
    if float_print {
        list_print(received_in:content[1]).
    } else {
        float_list_print(received_in:content[1],2).
    }
}

// check for any new messages and run any commands immediately
// do not return any value
function util_shbus_check_for_messages {

    IF NOT CORE:MESSAGES:EMPTY {
        SET received_msg TO CORE:MESSAGES:POP.
        //print_message(RECEIVED).
        if received_msg:CONTENT[0] = "Hello from FLCOM" {
            print "FLCOM says Hello!!!".
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
    }
}


function util_shbus_flush_messages {
    PARAMETER ECHO.
    UNTIL CORE:MESSAGES:EMPTY {
        SET RECEIVED TO CORE:MESSAGES:POP.
        IF ECHO {print RECEIVED:CONTENT.}
    }
}

// RX SECTION END
