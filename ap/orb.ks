
global AP_ORB_ENABLED is true.

local PARAM is readJson("param.json")["AP_ORB"].

local USE_STEERMAN to get_param(PARAM, "USE_STEER_MAN", true).
local USE_RCS to get_param(PARAM, "USE_RCS", true).
local USE_RW to get_param(PARAM, "USE_RW", true).

local K_RCS_STARBOARD is get_param(PARAM, "K_RCS_STARBOARD",1.0).
local K_RCS_TOP is get_param(PARAM, "K_RCS_TOP",1.0).
local K_RCS_FORE is get_param(PARAM, "K_RCS_FORE",1.0).

if USE_STEERMAN {
    set STEERINGMANAGER:PITCHPID:KP to get_param(PARAM, "P_KP", 8.0).
    set STEERINGMANAGER:PITCHPID:KI to get_param(PARAM, "P_KI", 8.0).
    set STEERINGMANAGER:PITCHPID:KD to get_param(PARAM, "P_KD", 12.0).

    set STEERINGMANAGER:YAWPID:KP to get_param(PARAM, "Y_KP", 8.0).
    set STEERINGMANAGER:YAWPID:KI to get_param(PARAM, "Y_KI", 8.0).
    set STEERINGMANAGER:YAWPID:KD to get_param(PARAM, "Y_KD", 12.0).

    set STEERINGMANAGER:ROLLPID:KP to get_param(PARAM, "R_KP", 8.0).
    set STEERINGMANAGER:ROLLPID:KI to get_param(PARAM, "R_KI", 8.0).
    set STEERINGMANAGER:ROLLPID:KD to get_param(PARAM, "R_KD", 12.0).
    print "got gains".
}

local orb_steer_direction is ship:facing.
local orb_throttle is 0.0.
local MAIN_ENGINE_IN_USE is false.
local RCS_IN_USE is false.

local RCS_MAX_DV is 100.0.

function ap_orb_nav_do {
    parameter vel_vec.
    parameter acc_vec.
    parameter head_dir.
    
    local delta_v is (vel_vec - ship:velocity:orbit).
    local alignment is ship:facing:forevector*delta_v:normalized.
    
    local STEERMAN_IN_USE is false.

    if USE_RCS and not MAIN_ENGINE_IN_USE {
        print "here".
        if (delta_v:mag > 0.05) and delta_v:mag < RCS_MAX_DV {
            set orb_steer_direction to head_dir.
            set STEERMAN_IN_USE to true.
            set RCS_IN_USE to true.

        } else {
            set STEERMAN_IN_USE to false.
            set RCS_IN_USE to false.
        }
    }

    // if not MAIN_ENGINE_IN_USE and (delta_v:mag > RCS_MAX_DV) {
    //     set MAIN_ENGINE_IN_USE to true.
    //     set orb_steer_direction to delta_v:direction.
    //     set STEERMAN_IN_USE to true.
    // } else if MAIN_ENGINE_IN_USE and (delta_v:mag < 0.1 or alignment < 0 ) {
    //     set MAIN_ENGINE_IN_USE to false.
    // }


    if USE_STEERMAN and not SAS {
        lock steering to orb_steer_direction.
    } else {
        unlock steering.
    }
    if MAIN_ENGINE_IN_USE {
        set orb_throttle to (choose 1.0 if alignment > 0.99 else 0.0).
        lock throttle to orb_throttle.
    } else {
        unlock throttle.
    }
    if RCS_IN_USE {
        set RCS to true.
        set ship:control:starboard to K_RCS_STARBOARD*(ship:facing:starvector*delta_v).
        set ship:control:top to K_RCS_TOP*(ship:facing:topvector*delta_v).
        set ship:control:fore to K_RCS_FORE*(ship:facing:forevector*delta_v).
    } else {
        set RCS to false.
        set ship:control:translation to V(0,0,0).
    }
    print "ap_orb_nav_do".
    print round_dec(delta_v:mag,1).
    print round_dec(alignment,2).
    print ap_orb_status_string().
}

function ap_orb_status_string {
    local hud_str is "".
    set hud_str to round_dec(orb_throttle,1).
    return hud_str.
}