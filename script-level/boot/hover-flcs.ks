// generic atmospheric flight control computer

wait until ship:loaded.

global DEV_FLAG is true.
global FETCH_SOURCE is (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED.
if FETCH_SOURCE { print "fetching resources from base".}

function fetch_and_run {
    parameter filehomepath.

    local filepath is filehomepath:replace("0:/", "").
    if FETCH_SOURCE {
        copypath(filehomepath, filepath).
    }
    if filepath:contains(".ks") {
        runoncepath(filepath).
    }
}

fetch_and_run("0:/koslib/util/common.ks").
if FETCH_SOURCE {
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
fetch_and_run("0:/koslib/ap/hover.ks").
fetch_and_run("0:/koslib/ap/nav.ks").
fetch_and_run("0:/koslib/ap/mode.ks").

GLOBAL BOOT_HOVER_FLCS_ENABLED IS true.

add_plane_globals().

// main loop
until false {
    util_shbus_rx_msg().
    util_shsys_spin_check().
    util_fldr_run_test().
    util_phys_update().

    ap_mode_update().
    ap_nav_display().

    if AP_MODE_PILOT {
        ap_hover_do().
    } else if AP_MODE_NAV {
        ap_hover_nav_do().
    } else {
        unlock THROTTLE.
        unlock STEERTING.
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    
    util_hud_info().
    wait 0.
}
