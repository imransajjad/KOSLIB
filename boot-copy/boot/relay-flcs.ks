
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
fetch_and_run("0:/koslib/ap/orb.ks").
fetch_and_run("0:/koslib/ap/nav.ks").
fetch_and_run("0:/koslib/ap/mode.ks").

GLOBAL BOOT_RELAY_FLCS_ENABLED IS true.


until false {
    get_plane_globals().

    util_shbus_rx_msg().
    util_shsys_spin_check().

    ap_mode_update().
    ap_nav_display().

    if not AP_MODE_NAV and not CONTROLCONNECTION:ISCONNECTED {
        ap_mode_set("NAV").
    }

    if AP_MODE_PILOT {
        ap_orb_w().
    } else if AP_MODE_NAV {
        ap_orb_nav_do().
    } else {
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    util_hud_info().
    wait 0.
}
