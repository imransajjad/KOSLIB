// Generic flight command system

function has_connection_to_base {
    if addons:available("RT") {
        return addons:RT:AVAILABLE AND addons:RT:HASKSCCONNECTION(SHIP).
    } else {
        return true.
    }
    return false.
}

WAIT UNTIL SHIP:LOADED.
IF has_connection_to_base() {
    COPYPATH("0:/koslib/util/common.ks","util_common").
    run once "util_common".
    COPYPATH("0:/param/"+string_acro(ship:name)+".json","param.json").
    
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/wp.ks","util_wp").
    COPYPATH("0:/koslib/util/hud.ks","util_hud").
    COPYPATH("0:/koslib/util/shbus.ks","util_shbus").
    COPYPATH("0:/koslib/util/term.ks","util_term").
    print "loaded resources from base".
}

wait 0.04.
wait 0.04.

run once "util_common".
run once "util_fldr".
run once "util_wp".
run once "util_hud".
run once "util_shbus".
run once "util_term".

GLOBAL BOOT_FLCOM_ENABLED IS true.

flush_core_messages().
util_term_do_command("unask flcs").
util_term_do_command("askhost flcs").

UNTIL FALSE {
    util_term_get_input().
}
