
global AP_NAV_ORB_ENABLED is true.

local in_mannode is false.

// function that is used when no wp is found,
// should just set nav parameters to execute present/future nodes
function ap_nav_orb_stick {
    set AP_NAV_VEL to ship:velocity:orbit.
    set AP_NAV_ACC to V(0,0,0).
    set AP_NAV_ATT to ship:facing.
}

function ap_nav_orb_status_string {
    local dstr is "".
    if eta:periapsis >= eta:apoapsis {
    set dstr to dstr+char(10)+"Ap "+round(ship:obt:apoapsis) +
        char(10)+ " ETA " + round(eta:apoapsis)+"s".
    } else {   
    set dstr to dstr+char(10)+"Pe "+round(ship:obt:periapsis) +
        char(10)+ "ETA " + round(eta:periapsis)+"s".
    }
    return dstr.
}