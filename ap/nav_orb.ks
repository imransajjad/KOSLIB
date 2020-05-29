
global AP_NAV_ORB_ENABLED is true.

function ap_nav_orb_stick {
    
}

function ap_nav_orb_do {

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