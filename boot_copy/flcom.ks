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
    COPYPATH("0:/koslib/util/shbus_tx.ks","util_shbus_tx").
    print "loaded resources from base".
}

wait 0.04.
wait 0.04.

run once "util_common".
run once "util_fldr".
run once "util_wp".
run once "util_hud".
run once "util_shbus_tx".

GLOBAL BOOT_FLCOM_ENABLED IS true.

flush_core_messages().
util_shbus_tx_do_command("sethost").

UNTIL FALSE {
    util_shbus_tx_get_input().
}
