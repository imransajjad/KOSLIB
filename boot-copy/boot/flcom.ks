// Generic flight command system

global DEV_FLAG is true.

wait until ship:loaded.

if (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED {
    COPYPATH("0:/koslib/util/common.ks","util-common").
    run once "util-common".
    get_param_file(core:element:name).
    
    COPYPATH("0:/koslib/util/fldr.ks","util-fldr").
    COPYPATH("0:/koslib/util/wp.ks","util-wp").
    COPYPATH("0:/koslib/util/hud.ks","util-hud").
    COPYPATH("0:/koslib/util/radar.ks","util-radar").
    COPYPATH("0:/koslib/util/shbus.ks","util-shbus").
    COPYPATH("0:/koslib/util/term.ks","util-term").
    print "loaded resources from base".
}

run once "util-common".
run once "util-fldr".
run once "util-wp".
run once "util-hud".
run once "util-shbus".
run once "util-radar".
run once "util-term".

GLOBAL BOOT_FLCOM_ENABLED IS true.

util_term_do_startup().

until false {
    util_shbus_rx_msg().
    util_term_get_input().
}
