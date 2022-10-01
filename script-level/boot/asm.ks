// Development of missile launch here

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
    get_boot_param_file("0:/param").
}

fetch_and_run("0:/koslib/util/wp.ks").
fetch_and_run("0:/koslib/util/fldr.ks").
fetch_and_run("0:/koslib/util/shsys.ks").
fetch_and_run("0:/koslib/util/shbus.ks").
fetch_and_run("0:/koslib/util/phys.ks").

fetch_and_run("0:/koslib/resource/blank.png").
fetch_and_run("0:/koslib/util/hud.ks").

fetch_and_run("0:/koslib/ap/aero-engines.ks").
fetch_and_run("0:/koslib/ap/aero-w.ks").
fetch_and_run("0:/koslib/ap/orb.ks").
fetch_and_run("0:/koslib/ap/nav.ks").
fetch_and_run("0:/koslib/ap/missile.ks").

add_plane_globals().

util_shsys_set_spin("engine", true).

util_shsys_spin_check().
util_shsys_do_action("lock_target").

util_shbus_tx_msg("SYS_CB_OPEN",list(),list("flcs")).
util_shsys_set_spin("bays", true).
util_shsys_spin_check().

util_shbus_tx_msg("SYS_PL_AWAY",list(ship:name+" Probe"),list("flcs")).
util_shbus_tx_msg("SYS_CB_CLOSE",list(ship:name+" Probe"),list("flcs")).

util_shsys_cleanup().
util_shbus_disconnect().

util_shsys_do_action("reaction_wheels_activate").
util_shsys_do_action("decouple").
print get_com_offset().

util_shbus_set_ship_router(true).
util_shsys_set_spin("separate",true).

util_shsys_spin_check().

util_shsys_do_action("thrust_max").

ap_missile_guide(). // will use nav to do this

set fwp to util_wp_arg_lex(list(300,0.04),"tar").
util_wp_add(-1,fwp).

until false {
    util_shbus_rx_msg().
    util_shsys_spin_check().

    ap_nav_display().

    ap_orb_nav_do().

    // util_hud_info().
    wait 0.
}