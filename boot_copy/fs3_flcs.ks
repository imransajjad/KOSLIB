// testing on fighter stealth 3

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
    COPYPATH("0:/koslib/param/fs3.ks","param").

    COPYPATH("0:/koslib/util/common.ks","util_common").

    COPYPATH("0:/koslib/util/wp.ks","util_wp").
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/shsys.ks","util_shsys").
    COPYPATH("0:/koslib/util/shbus_rx.ks","util_shbus_rx").

    COPYPATH("0:/koslib/resource/blank.png","blank_tex").
    COPYPATH("0:/koslib/util/hud.ks","util_hud").

    COPYPATH("0:/koslib/ap/engines.ks","ap_engines").
    COPYPATH("0:/koslib/ap/flcs_rot.ks","ap_flcs_rot").
    COPYPATH("0:/koslib/ap/nav.ks","ap_nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap_mode").
    print "loaded resources from base".
}



// Global plane data

SET KERBIN TO BODY("Kerbin").

LOCK pilot_input_u0 TO SHIP:CONTROL:PILOTMAINTHROTTLE.
LOCK pilot_input_u1 TO sat(3.0*SHIP:CONTROL:PILOTPITCH, 1.0).
LOCK pilot_input_u2 TO sat(3.0*SHIP:CONTROL:PILOTYAW, 1.0).
LOCK pilot_input_u3 TO sat(2.0*SHIP:CONTROL:PILOTROLL, 1.0).

LOCK DELTA_FACE_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
LOCK pitch TO (mod(DELTA_FACE_UP:pitch+90,180)-90).
LOCK roll TO (180-DELTA_FACE_UP:roll).
LOCK yaw TO (360-DELTA_FACE_UP:yaw).

LOCK vel TO SHIP:AIRSPEED.

LOCK DELTA_SRFPRO_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:SRFPROGRADE).
LOCK vel_pitch TO (mod(DELTA_SRFPRO_UP:pitch+90,180)-90).
LOCK vel_bear TO (360-DELTA_SRFPRO_UP:yaw).

LOCK DELTA_PRO_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:PROGRADE).
LOCK orb_vel_pitch TO (mod(DELTA_PRO_UP:pitch+90,180)-90).
LOCK orb_vel_bear TO (360-DELTA_PRO_UP:yaw).

global main_engine_name is "turboJet".

run once "param".
run once "util_common".

run once "util_wp".
run once "util_fldr".
run once "util_shsys".
run once "util_shbus_rx".

run once "util_hud".

run once "ap_engines".
run once "ap_flcs_rot".
run once "ap_nav".
run once "ap_mode".

// define disabled flags
IF NOT (DEFINED UTIL_HUD_ENABLED) { GLOBAL UTIL_HUD_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHBUS_RX_ENABLED) { GLOBAL UTIL_SHBUS_RX_ENABLED IS false.}
GLOBAL BOOT_FS3_FLCS_ENABLED IS true.




if UTIL_SHBUS_RX_ENABLED {
    util_shbus_flush_messages(true).
}

// main loop
UNTIL false {
    if UTIL_SHBUS_RX_ENABLED {
        util_shbus_check_for_messages().
    }

    ap_mode_update().
    ap_nav_disp().

    if AP_FLCS_CHECK() {
        ap_engine_throttle_map().
        ap_flcs_rot(pilot_input_u1, pilot_input_u2, pilot_input_u3).
    } else if AP_VEL_CHECK() {
        ap_engine_throttle_auto().
        ap_flcs_rot(pilot_input_u1, pilot_input_u2, pilot_input_u3).
    } else if AP_NAV_CHECK() {
        ap_engine_throttle_auto().
        ap_nav_do_flcs_rot().
    } else {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    
    if UTIL_HUD_ENABLED {
        util_hud_vec_info().
        util_hud_info().
    }
    WAIT 0.0.
}
