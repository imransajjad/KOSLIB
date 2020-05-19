
function ap_nav_orb_stick {
    
}

function ap_nav_do_orb {

}

function ap_nav_orb_status_string {
    local dstr is "/".
    if eta:periapsis >= eta:apoapsis {
    set dstr to dstr+"Ap "+round(ship:obt:apoapsis) + 
        char(10)+ " ETA " + round(eta:apoapsis)+"s".
    } else {   
    set dstr to dstr+"Pe "+round(ship:obt:periapsis) + 
        char(10)+ "ETA " + round(eta:periapsis)+"s".
    }
    return dstr.
}