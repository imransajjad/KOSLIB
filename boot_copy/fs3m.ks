// Development of missile launch
// testing on fighter stealth 3

function has_connection_to_base {
    if addons:available("RT") {
        return addons:RT:AVAILABLE AND addons:RT:HASKSCCONNECTION(SHIP).
    } else {
        return true.
    }
    return false.
}

WAIT UNTIL SHIP:LOADED.
IF has_connection_to_base() {
    COPYPATH("0:/koslib/util/common.ks","util_common").
    COPYPATH("0:/koslib/ap/missile.ks","ap_missile").
    print "loaded resources from base".
}

run once "util_common".
run once "ap_missile".

ap_missile_init().
ap_missile_wait().
ap_missile_setup_separate().
ap_missile_guide().
