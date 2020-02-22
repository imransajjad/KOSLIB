
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
    COPYPATH("0:/param/kr2.ks","param").
    COPYPATH("0:/koslib/util/common.ks","util_common").
    
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/shbus_rx.ks","util_shbus_rx").
    COPYPATH("0:/koslib/util/shsys.ks","util_shsys").

    COPYPATH("0:/koslib/ap/snav.ks","ap_snav").
    COPYPATH("0:/koslib/ap/mode.ks","ap_mode").
    print "loaded resources from base".
}

global main_antenna_name is "main_antenna".

run once "param".
run once "util_common".
run once "util_shbus_rx".
run once "util_shsys".

run once "ap_mode".
run once "ap_snav".

// define disabled flags
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHBUS_RX_ENABLED) { GLOBAL UTIL_SHBUS_RX_ENABLED IS false.}
GLOBAL BOOT_RCOM_ENABLED IS true.


UNTIL FALSE {
    if UTIL_SHBUS_RX_ENABLED {
        util_shbus_check_for_messages().
    }
    if UTIL_SHSYS_ENABLED {
        util_shsys_check().
    }

    ap_mode_update().

    if AP_FLCS_CHECK() {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    } else if AP_NAV_CHECK() {
        ap_nav_do_man().
    } else {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    wait 0.02.
}
