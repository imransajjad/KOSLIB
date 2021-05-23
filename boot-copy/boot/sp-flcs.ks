// atmospheric flight control computer + orbital control computer

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

    COPYPATH("0:/koslib/ap/aero-engines.ks","ap-aero-engines").
    COPYPATH("0:/koslib/ap/aero-w.ks","ap-aero-w").
    COPYPATH("0:/koslib/ap/orb.ks","ap-orb").
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

run once "ap-aero-engines".
run once "ap-aero-w".
run once "ap-orb".
run once "ap-nav".
run once "ap-mode".

GLOBAL BOOT_SP_FLCS_ENABLED IS true.

add_plane_globals().

// main loop
until false {
    util_shbus_rx_msg().
    util_shsys_spin_check().
    util_fldr_run_test().
    util_phys_update().

    ap_mode_update().
    ap_nav_display().

    if SHIP:Q > 0.0001 {
        ap_orb_lock_controls(false).
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
    } else {
        if not AP_MODE_NAV and not CONTROLCONNECTION:ISCONNECTED {
            ap_mode_set("NAV").
        }

        if AP_MODE_NAV {
            ap_orb_nav_do().
        } else {
            ap_orb_lock_controls(false).
            SET SHIP:CONTROL:NEUTRALIZE to true.
        }
    }
    
    util_hud_info().
    wait 0.
}
