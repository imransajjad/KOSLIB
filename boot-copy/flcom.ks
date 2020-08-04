// Generic flight command system

function has_connection_to_base {
    if addons:available("RT") {
        return addons:RT:AVAILABLE AND addons:RT:HASKSCCONNECTION(SHIP).
    } else {
        return true.
    }
    return false.
}

global DEV_FLAG is true.

WAIT UNTIL SHIP:LOADED.
if (DEV_FLAG or not exists("param.json")) and has_connection_to_base() {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_ship_param_file().
    
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/wp.ks","util-wp").
    COPYPATH("0:/koslib/util/hud.ks","util-hud").
    COPYPATH("0:/koslib/util/radar.ks","util-radar").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").
    COPYPATH("0:/koslib/util/term.ks","util-term").
    print "loaded resources from base".
}

wait 0.04.
wait 0.04.

run once "util-common".
run once "util-fldr".
run once "util-wp".
run once "util-hud".
run once "util-shbus".
run once "util-radar".
run once "util-term".

GLOBAL BOOT_FLCOM_ENABLED IS true.


util_term_do_startup().

until false {
    util_shbus_rx_msg().
    util_term_get_input().
}
