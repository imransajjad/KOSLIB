// generic atmospheric flight control computer

wait until ship:loaded.

global DEV_FLAG is true.
global FETCH_SOURCE is (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED.
if FETCH_SOURCE { print "fetching resources from base".}
if core:tag = "" { set core:tag to "flcs". }

if FETCH_SOURCE {
    copypath("0:/koslib/util/common.ks","koslib/util/common.ks").
    runoncepath("koslib/util/common.ks").
    get_element_param_file("0:/param").
}

fetch_and_run("0:/koslib/util/wp.ks").
fetch_and_run("0:/koslib/util/fldr.ks").
fetch_and_run("0:/koslib/util/shsys.ks").
fetch_and_run("0:/koslib/util/shbus.ks").
fetch_and_run("0:/koslib/util/phys.ks").

fetch_and_run("0:/koslib/resource/blank.png").
fetch_and_run("0:/koslib/util/hud.ks").

fetch_and_run("0:/koslib/ap/stick.ks").
fetch_and_run("0:/koslib/ap/aero-engines.ks").
fetch_and_run("0:/koslib/ap/aero-w.ks").
fetch_and_run("0:/koslib/ap/nav.ks").
fetch_and_run("0:/koslib/ap/nav/srf.ks").
fetch_and_run("0:/koslib/ap/nav/tar.ks").
fetch_and_run("0:/koslib/ap/mode.ks").

GLOBAL BOOT_AERO_FLCS_ENABLED IS true.

// add_plane_globals().

// main loop
until false {
    get_plane_globals().

    util_shbus_rx_msg().
    util_shsys_spin_check().
    util_fldr_run_test().
    util_phys_update().

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
    wait 0.0.
}
