
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

    COPYPATH("0:/koslib/ap/nav.ks","ap_nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap_mode").
    print "loaded resources from base".
}

LOCK vel TO (choose SHIP:AIRSPEED if ship:altitude < 36000 else SHIP:VELOCITY:ORBIT:mag).

LOCK DELTA_PRO_UP TO R(90,0,0)*(-SHIP:UP)*
    (choose SHIP:SRFPROGRADE if ship:altitude < 36000 else SHIP:PROGRADE).
LOCK vel_pitch TO (mod(DELTA_PRO_UP:pitch+90,180)-90).
LOCK vel_bear TO (360-DELTA_PRO_UP:yaw).

global aux_antenna_name is "omni_antenna".

run once "param".
run once "util_common".
run once "util_shbus_rx".
run once "util_shsys".

run once "ap_mode".
run once "ap_nav".

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
    if not AP_MODE_NAV and not has_connection_to_base(){
        ap_mode_set("NAV").
    }

    if AP_MODE_FLCS {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    } else if AP_MODE_NAV {
        ap_nav_do_man().
    } else {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    wait 0.02.
}
