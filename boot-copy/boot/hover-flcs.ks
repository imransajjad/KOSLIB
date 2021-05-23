// generic atmospheric flight control computer

wait until ship:loaded.

global DEV_FLAG is true.

if (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_param_file(core:element:name).

    COPYPATH("0:/koslib/util/wp.ks","util-wp").
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/shsys.ks","util-shsys").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").
    COPYPATH("0:/koslib/util/phys.ks","util-phys").

    COPYPATH("0:/koslib/resource/blank.png","blank-tex").
    COPYPATH("0:/koslib/util/hud.ks","util-hud").

    COPYPATH("0:/koslib/ap/hover.ks","ap-hover").
    COPYPATH("0:/koslib/ap/nav.ks","ap-nav").
    COPYPATH("0:/koslib/ap/mode.ks","ap-mode").
    print "loaded resources from base".
}

run once "util-common".
run once "util-wp".
run once "util-fldr".
run once "util-shsys".
run once "util-shbus".
run once "util-phys".

run once "util-hud".

run once "ap-hover".
run once "ap-nav".
run once "ap-mode".

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
