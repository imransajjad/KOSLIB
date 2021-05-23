
wait until ship:loaded.
wait 0.25. // so that connection is established if possible.

global DEV_FLAG is true.


if (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_param_file(core:element:name).
    
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").
    COPYPATH("0:/koslib/util/shsys.ks","util-shsys").
    COPYPATH("0:/koslib/util/hud.ks","util-hud").
    COPYPATH("0:/koslib/util/wp.ks","util-wp").
    COPYPATH("0:/koslib/util/phys.ks","util-phys").

    COPYPATH("0:/koslib/ap/orb.ks","ap-orb").
    COPYPATH("0:/koslib/ap/nav.ks","ap-nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap-mode").
    print "loaded resources from base".
}

run once "util-common".
run once "util-fldr".
run once "util-shbus".
run once "util-shsys".
run once "util-hud".
run once "util-wp".
run once "util-phys".

run once "ap-orb".
run once "ap-mode".
run once "ap-nav".

GLOBAL BOOT_RELAY_FLCS_ENABLED IS true.

add_plane_globals().

until false {
    util_shbus_rx_msg().
    util_shsys_spin_check().

    ap_mode_update().
    ap_nav_display().

    if not AP_MODE_NAV and not CONTROLCONNECTION:ISCONNECTED {
        ap_mode_set("NAV").
    }

    if AP_MODE_NAV {
        ap_orb_nav_do().
    } else {
        ap_orb_lock_controls(false).
        SET SHIP:CONTROL:NEUTRALIZE to true.
    }
    util_hud_info().
    wait 0.
}
