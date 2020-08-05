// generic atmospheric flight control computer

wait until ship:loaded.
wait 0.25.

global DEV_FLAG is true.

if (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_ship_param_file().

    COPYPATH("0:/koslib/util/wp.ks","util-wp").
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/shsys.ks","util-shsys").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").

    COPYPATH("0:/koslib/resource/blank.png","blank-tex").
    COPYPATH("0:/koslib/util/hud.ks","util-hud").

    COPYPATH("0:/koslib/ap/aero-engines.ks","ap-aero-engines").
    COPYPATH("0:/koslib/ap/aero-w.ks","ap-aero-w").
    COPYPATH("0:/koslib/ap/nav.ks","ap-nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap-mode").
    print "loaded resources from base".
}

// Global plane data

when true then {
    set DELTA_FACE_UP to R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
    set pitch to (mod(DELTA_FACE_UP:pitch+90,180)-90).
    set roll to (180-DELTA_FACE_UP:roll).
    set yaw to (360-DELTA_FACE_UP:yaw).

    set DELTA_PRO_UP to R(90,0,0)*(-SHIP:UP)*
        (choose SHIP:srfprograde if ship:altitude < 36000 else SHIP:prograde).
    set vel_pitch to (mod(DELTA_PRO_UP:pitch+90,180)-90).
    set vel_bear to (360-DELTA_PRO_UP:yaw).
    
    return true.
}
wait 0.

run once "util-common".

run once "util-wp".
run once "util-fldr".
run once "util-shsys".
run once "util-shbus".

run once "util-hud".

run once "ap-aero-engines".
run once "ap-aero-w".
run once "ap-nav".
run once "ap-mode".

GLOBAL BOOT_AERO_FLCS_ENABLED IS true.

// main loop
until false {
    util_shbus_rx_msg().
    util_shsys_spin_check().

    ap_mode_update().
    ap_nav_display().

    if AP_MODE_PILOT {
        ap_aero_engine_throttle_map().
        ap_aero_w_do().
    } else if AP_MODE_VEL {
        ap_aero_engine_throttle_auto().
        ap_aero_w_do().
    } else if AP_MODE_NAV {
        ap_aero_engine_throttle_auto().
        ap_aero_w_nav_do().
    } else {
        unlock THROTTLE.
        unlock STEERTING.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    
    util_hud_info().
    wait 0.
}
