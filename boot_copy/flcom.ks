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
    COPYPATH("0:/koslib/util/common.ks","util_common").
    run once "util_common".
    COPYPATH("0:/param/"+string_acro(ship:name)+".json","param.json").
    
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/wp.ks","util_wp").
    COPYPATH("0:/koslib/util/hud.ks","util_hud").
    COPYPATH("0:/koslib/util/radar.ks","util_radar").
    COPYPATH("0:/koslib/util/shbus.ks","util_shbus").
    COPYPATH("0:/koslib/util/term.ks","util_term").
    print "loaded resources from base".
}
run once "util_common".
global SHIP_TAG_IN_PARAMS is
        get_param( readJson("1:/param.json"), "control_tag", string_acro(ship:name)).
spin_if_not_us().

wait 0.04.
wait 0.04.

run once "util_common".
run once "util_fldr".
run once "util_wp".
run once "util_hud".
run once "util_shbus".
run once "util_radar".
run once "util_term".

GLOBAL BOOT_FLCOM_ENABLED IS true.

if defined UTIL_TERM_ENABLED {
    util_term_do_command(get_param(readJson("1:/param.json")["UTIL_TERM"], "STARTUP_COMMAND","")).
}

UNTIL FALSE {
    spin_if_not_us().
    util_term_get_input().
}
