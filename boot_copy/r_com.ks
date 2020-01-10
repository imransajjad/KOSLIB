
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
    COPYPATH("0:/koslib/param/r_com.ks","param").
    COPYPATH("0:/koslib/util/common.ks","util_common").
    
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/shbus_rx.ks","util_shbus_rx").
    print "loaded resources from base".
}

run once "param".
run once "util_common".
run once "util_fldr".
run once "util_shbus_rx".


global MAIN_ENGINE is 0.
for e in SHIP:PARTSDUBBED("turboJet"){
    set MAIN_ENGINE TO e.
    PRINT "Found Engine "+ MAIN_ENGINE:NAME.
}

UNTIL FALSE {
    util_fldr_log_on_ag().
}
