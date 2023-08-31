// Generic flight command system

wait until ship:loaded.

global DEV_FLAG is true.
global FETCH_SOURCE is (DEV_FLAG or not exists("param.json")) and HOMECONNECTION:ISCONNECTED.
if FETCH_SOURCE { print "fetching resources from base".}
if core:tag = "" { set core:tag to "flcom". }

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
fetch_and_run("0:/koslib/util/shbus.ks").
fetch_and_run("0:/koslib/util/radar.ks").
fetch_and_run("0:/koslib/util/term.ks").
fetch_and_run("0:/koslib/util/hud.ks").

GLOBAL BOOT_FLCOM_ENABLED IS true.

util_term_do_startup().

until false {
    util_shbus_rx_msg().
    util_term_get_input().
}
