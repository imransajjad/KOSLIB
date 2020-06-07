
global AP_NAV_ORB_ENABLED is true.

if readJson("param.json"):haskey("AP_STEER_MAN") {
    local PARAM is readJson("param.json")["AP_STEER_MAN"].

    set STEERINGMANAGER:PITCHPID:KP to get_param(PARAM, "P_KP", 8.0).
    set STEERINGMANAGER:PITCHPID:KI to get_param(PARAM, "P_KI", 8.0).
    set STEERINGMANAGER:PITCHPID:KD to get_param(PARAM, "P_KD", 12.0).

    set STEERINGMANAGER:YAWPID:KP to get_param(PARAM, "Y_KP", 8.0).
    set STEERINGMANAGER:YAWPID:KI to get_param(PARAM, "Y_KI", 8.0).
    set STEERINGMANAGER:YAWPID:KD to get_param(PARAM, "Y_KD", 12.0).

    set STEERINGMANAGER:ROLLPID:KP to get_param(PARAM, "R_KP", 8.0).
    set STEERINGMANAGER:ROLLPID:KI to get_param(PARAM, "R_KI", 8.0).
    set STEERINGMANAGER:ROLLPID:KD to get_param(PARAM, "R_KD", 12.0).
}

local in_mannode is false.

function ap_nav_orb_stick {
    
}

function ap_nav_orb_do {
    if in_mannode {
        lock STEERING to AP_NAV_ATT.
    }
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