// generic atmospheric flight control computer

function has_connection_to_base {
    if addons:available("RT") {
        return addons:RT:AVAILABLE AND addons:RT:HASKSCCONNECTION(SHIP).
    } else {
        return true.
    }
}

WAIT UNTIL SHIP:LOADED.
IF has_connection_to_base() {
    COPYPATH("0:/koslib/util/common.ks","util_common").
    run once "util_common".
    COPYPATH("0:/param/"+string_acro(ship:name)+".json","param.json").

    COPYPATH("0:/koslib/util/wp.ks","util_wp").
    COPYPATH("0:/koslib/util/fldr.ks","util_fldr").
    COPYPATH("0:/koslib/util/shsys.ks","util_shsys").
    COPYPATH("0:/koslib/util/shbus.ks","util_shbus").

    COPYPATH("0:/koslib/resource/blank.png","blank_tex").
    COPYPATH("0:/koslib/util/hud.ks","util_hud").

    COPYPATH("0:/koslib/ap/engines.ks","ap_engines").
    COPYPATH("0:/koslib/ap/aero_rot.ks","ap_aero_rot").
    COPYPATH("0:/koslib/ap/nav_srf.ks","ap_nav_srf").
    COPYPATH("0:/koslib/ap/nav_orb.ks","ap_nav_orb").
    COPYPATH("0:/koslib/ap/nav_tar.ks","ap_nav_tar").
    COPYPATH("0:/koslib/ap/nav.ks","ap_nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap_mode").
    print "loaded resources from base".
}

// Global plane data

LOCK pilot_input_u0 TO SHIP:CONTROL:PILOTMAINTHROTTLE.
LOCK pilot_input_u1 TO sat(3.0*SHIP:CONTROL:PILOTPITCH, 1.0).
LOCK pilot_input_u2 TO sat(3.0*SHIP:CONTROL:PILOTYAW, 1.0).
LOCK pilot_input_u3 TO sat(3.0*SHIP:CONTROL:PILOTROLL, 1.0).

LOCK DELTA_FACE_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
LOCK pitch TO (mod(DELTA_FACE_UP:pitch+90,180)-90).
LOCK roll TO (180-DELTA_FACE_UP:roll).
LOCK yaw TO (360-DELTA_FACE_UP:yaw).

LOCK vel TO (choose SHIP:AIRSPEED if ship:altitude < 36000 else SHIP:VELOCITY:ORBIT:mag).
LOCK vel_prograde TO (choose ship:srfprograde if ship:altitude < 36000 else ship:prograde).

LOCK DELTA_PRO_UP TO R(90,0,0)*(-SHIP:UP)*
    (choose SHIP:srfprograde if ship:altitude < 36000 else SHIP:prograde).
LOCK vel_pitch TO (mod(DELTA_PRO_UP:pitch+90,180)-90).
LOCK vel_bear TO (360-DELTA_PRO_UP:yaw).

run once "util_common".

run once "util_wp".
run once "util_fldr".
run once "util_shsys".
run once "util_shbus".

run once "util_hud".

run once "ap_engines".
run once "ap_aero_rot".
run once "ap_nav_srf".
run once "ap_nav_orb".
run once "ap_nav_tar".
run once "ap_nav".
run once "ap_mode".

GLOBAL BOOT_AERO_FLCS_ENABLED IS true.

util_hud_init().
flush_core_messages().

// main loop
UNTIL false {
    util_shbus_rx_msg().
    util_shsys_check().

    ap_mode_update().
    ap_nav_display().

    if AP_MODE_PILOT {
        ap_engine_throttle_map().
        ap_aero_rot_do(pilot_input_u1, pilot_input_u2, pilot_input_u3).
    } else if AP_MODE_VEL {
        ap_engine_throttle_auto().
        ap_aero_rot_do(pilot_input_u1, pilot_input_u2, pilot_input_u3).
    } else if AP_MODE_NAV {
        ap_engine_throttle_auto().
        ap_nav_do().
    } else {
        unlock THROTTLE.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    
    util_hud_info().
    WAIT 0.02.
}
