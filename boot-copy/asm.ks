// Development of missile launch here

wait until ship:loaded.
wait 1.0.

IF HOMECONNECTION:ISCONNECTED {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_param_file().

    COPYPATH("0:/koslib/util/hud.ks","util-hud").
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/shsys.ks","util-shsys").
    COPYPATH("0:/koslib/util/phys.ks","util-phys").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").
    COPYPATH("0:/koslib/util/wp.ks","util-wp").

    COPYPATH("0:/koslib/ap/orb.ks","ap-orb").
    COPYPATH("0:/koslib/ap/nav.ks","ap-nav").

    COPYPATH("0:/koslib/ap/missile.ks","ap-missile").
    print "loaded resources from base".
}

global lock DELTA_FACE_UP to R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
global lock pitch to (mod(DELTA_FACE_UP:pitch+90,180)-90).
global lock roll to (180-DELTA_FACE_UP:roll).
global lock yaw to (360-DELTA_FACE_UP:yaw).

global lock DELTA_PRO_UP to R(90,0,0)*(-SHIP:UP)*
    (choose SHIP:srfprograde if ship:altitude < 36000 else SHIP:prograde).
global lock vel_pitch to (mod(DELTA_PRO_UP:pitch+90,180)-90).
global lock vel_bear to (360-DELTA_PRO_UP:yaw).
// when true then {
    
//     return true.
// }
wait 0.

run once "util-common".
// run once "util-hud".
run once "util-fldr".
run once "util-shsys".
run once "util-phys".
run once "util-shbus".
run once "util-wp".

run once "ap-orb".
run once "ap-nav".

run once "ap-missile".

wait 2.0.

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