
global AP_ORB_ENABLED is true.

local PARAM is readJson("param.json")["AP_ORB"].

local USE_STEERMAN to get_param(PARAM, "USE_STEER_MAN", true).
local USE_RCS to get_param(PARAM, "USE_RCS", true).
local USE_RW to get_param(PARAM, "USE_RW", true).

local MIN_ALIGN is cos(get_param(PARAM, "STEER_MAX_ANGLE", 1.0)).

local USE_ORB_ENGINE to get_param(PARAM, "USE_ORB_ENGINE", true).

local K_RCS_STARBOARD is get_param(PARAM, "K_RCS_STARBOARD",1.0).
local K_RCS_TOP is get_param(PARAM, "K_RCS_TOP",1.0).
local K_RCS_FORE is get_param(PARAM, "K_RCS_FORE",1.0).
local K_ORB_ENGINE_FORE is get_param(PARAM, "K_ORB_ENGINE_FORE",0.5).

local RCS_MAX_DV is get_param(PARAM, "RCS_MAX_DV", 10.0).
local RCS_MIN_DV is get_param(PARAM, "RCS_MIN_DV", 0.05).
local RCS_MIN_U is get_param(PARAM, "RCS_MIN_U", 0.05).
local RCS_MIN_ALIGN is cos(get_param(PARAM, "RCS_MAX_ANGLE", 10.0)).
local RCS_THRUST is get_param(PARAM, "RCS_THRUST", 1.0).

local lock MTR to 0*ship:mass/(2*RCS_THRUST).

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
local orb_rcs_vector is V(0,0,0).
local orb_throttle is 0.0.
local STEER_RCS is false.
local BURN_ACTIVE is false.

local delta_v is V(0,0,0).
local total_head_align is 0.
local RCSvec to V(1,0,0).
local BURNvec to V(1,0,0).
local RCSon to false.

function ap_orb_nav_do {
    parameter vel_vec is AP_NAV_VEL. // defaults are globals defined in AP_NAV
    parameter acc_vec is AP_NAV_ACC.
    parameter head_dir is AP_NAV_ATT.
    
    set delta_v to (vel_vec - ship:velocity:orbit).


    local delta_v_mag is abs(delta_v*head_dir:starvector + delta_v*head_dir:topvector + delta_v*1*head_dir:topvector).
    
    if not SAS {
        if USE_ORB_ENGINE {
            set orb_throttle to (choose K_ORB_ENGINE_FORE*ship:facing:forevector*delta_v if 
            BURN_ACTIVE and ship:facing:forevector*delta_v:normalized > 0.99 else 0).
            if not BURN_ACTIVE and ((USE_RCS and delta_v:mag > RCS_MAX_DV) or (not USE_RCS and delta_v:mag > 0.05)) {
                lock throttle to orb_throttle.
                set BURNvec to delta_v:normalized.
                set BURN_ACTIVE to true.
            } else if BURN_ACTIVE and (BURNvec*delta_v < 0.05) {
                set orb_throttle to 0.0.
                set BURN_ACTIVE to false.
                unlock throttle.
            }
        }

       if USE_STEERMAN {
            if not BURN_ACTIVE {
                set orb_steer_direction to head_dir.
            } else {
                set orb_steer_direction to BURNvec:direction.
            }
            local head_error is (-ship:facing)*orb_steer_direction.
            set total_head_align to 0.5*head_error:forevector*V(0,0,1) + 0.5*head_error:starvector*V(1,0,0).
            if total_head_align < MIN_ALIGN {
                lock steering to orb_steer_direction.
                if (not USE_RW) { set STEER_RCS to true. }
            } else {
                unlock steering.
                if (not USE_RW) { set STEER_RCS to false. }
            }
             
        }
        if USE_RCS and throttle = 0.0 {

            local translation_control is V(
                K_RCS_STARBOARD*(ship:facing:starvector*delta_v) + ship:facing:starvector*acc_vec*MTR,
                K_RCS_TOP*(ship:facing:topvector*delta_v) + ship:facing:topvector*acc_vec*MTR,
                K_RCS_FORE*(ship:facing:forevector*delta_v) + ship:facing:forevector*acc_vec*MTR).
            local translation_on is V(
                10*(ship:facing:starvector*delta_v),
                10*(ship:facing:topvector*delta_v),
                1*(ship:facing:forevector*delta_v)).

            if USE_RW and (total_head_align < RCS_MIN_ALIGN)  or (delta_v:mag > RCS_MAX_DV) {
                set ship:control:translation to V(0,0,0).
                set RCSon to false.
                set RCS to false.
            } else if not RCSon and ((translation_control:normalized*delta_v > RCS_MIN_DV) or STEER_RCS) {
                set ship:control:translation to translation_control.
                set RCSvec to delta_v:normalized.
                set RCS to true.
                set RCSon to true.
            } else if RCSon and (delta_v*RCSvec <= 0 and not STEER_RCS) {
                set RCS to false.
                set RCSon to false.
                set ship:control:translation to V(0,0,0).
            }
        }
    } else {
        unlock throttle.
        unlock steering.
    }
}

function ap_orb_status_string {
    local hud_str is "".

    if (true) { // debug
        set hud_str to hud_str + "Othr " + round_dec(orb_throttle,1) +
            (choose char(10) + "StRCS" if STEER_RCS else "") +
            (choose char(10) + "BURN " if BURN_ACTIVE else "").
    }

    if (true) {
        set hud_str to hud_str + char(10) + "align  " + round_dec(total_head_align,3) + char(10) + 
            "RCSalign " + round_dec(delta_v*(ship:facing*ship:control:translation),3) + char(10) +
            "dv "  + round_dec(delta_v:mag,3) + "(" + round_dec(ship:facing:starvector*delta_v,2) + "," +
                round_dec(ship:facing:topvector*delta_v,2) + "," +
                round_dec(ship:facing:forevector*delta_v,2) +")".
    }
    
    return hud_str.
}