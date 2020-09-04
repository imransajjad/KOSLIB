
global AP_ORB_ENABLED is true.

local PARAM is readJson("param.json")["AP_ORB"].

local USE_STEERMAN to get_param(PARAM, "USE_STEER_MAN", true).
local USE_RCS to get_param(PARAM, "USE_RCS", true).
local USE_RCS_STEER to get_param(PARAM, "USE_RCS_STEER", false).

local MIN_ALIGN is cos(get_param(PARAM, "STEER_MAX_ANGLE", 1.0)).

local K_RCS_STARBOARD is get_param(PARAM, "K_RCS_STARBOARD",1.0).
local K_RCS_TOP is get_param(PARAM, "K_RCS_TOP",1.0).
local K_RCS_FORE is get_param(PARAM, "K_RCS_FORE",1.0).
local K_ORB_ENGINE_FORE is get_param(PARAM, "K_ORB_ENGINE_FORE",0.5).

local ENGINE_VEC is get_param(PARAM, "ENGINE_VEC", V(0,0,1)).

local RCS_MAX_DV is get_param(PARAM, "RCS_MAX_DV", 10.0).
local RCS_MIN_ALIGN is cos(get_param(PARAM, "RCS_MAX_ANGLE", 10.0)).
local RCS_THRUST is get_param(PARAM, "RCS_THRUST", 1.0).

local lock MTR to 0*ship:mass/(2*RCS_THRUST).

local lock omega to RAD2DEG*ship:angularVel.

if USE_STEERMAN {
    set STEERINGMANAGER:MAXSTOPPINGTIME to 1000.
    set STEERINGMANAGER:PITCHPID:KP to get_param(PARAM, "P_KP", 8.0).
    set STEERINGMANAGER:PITCHPID:KI to get_param(PARAM, "P_KI", 8.0).
    set STEERINGMANAGER:PITCHPID:KD to get_param(PARAM, "P_KD", 12.0).

    set STEERINGMANAGER:YAWPID:KP to get_param(PARAM, "Y_KP", 8.0).
    set STEERINGMANAGER:YAWPID:KI to get_param(PARAM, "Y_KI", 8.0).
    set STEERINGMANAGER:YAWPID:KD to get_param(PARAM, "Y_KD", 12.0).

    set STEERINGMANAGER:ROLLPID:KP to get_param(PARAM, "R_KP", 8.0).
    set STEERINGMANAGER:ROLLPID:KI to get_param(PARAM, "R_KI", 8.0).
    set STEERINGMANAGER:ROLLPID:KD to get_param(PARAM, "R_KD", 12.0).
    print "orb gains " + STEERINGMANAGER:PITCHPID:KP + " "
                        + STEERINGMANAGER:PITCHPID:KI + " "
                        + STEERINGMANAGER:PITCHPID:KD.
}

local lock ship_vel to (-SHIP:FACING)*ship:velocity:surface:direction.
local lock alpha to wrap_angle(ship_vel:pitch).
local lock beta to wrap_angle(-ship_vel:yaw).

local lock HAVE_FUEL to (ship:liquidfuel > 0.01).
local lock SRFV_MARGIN to (choose 200 if AP_NAV_IN_SURFACE else 0).

local orb_steer_direction is ship:facing.
local total_head_align is 0.

local orb_throttle is 0.0.
local DO_BURN is false.
local delta_v is V(0,0,0).
local delta_a is V(0,0,0).
local BURNvec to V(0,0,1).

local RCSon to false.

local alpha_c is 0.0.
local beta_c is 0.0.
local W_A is 0.8.


// for a command below a minumum actuator force,
// return a pulsed output to apply averaged out actuator force
local function pwm_alivezone {
    parameter u_in.
    parameter min_act is 0.1.

    local period is 0.4. // min pulse 0.04 seconds

    if abs(u_in) < min_act {
        local act_on is ( remainder(time:seconds,period) < abs(u_in/min_act)*period ).
        return choose min_act*sign(u_in) if act_on else 0.0.
    } else {
        return u_in.
    }

}

// return if orb engine is usable
local function orb_thrust {
    list engines in engine_list.
    local f is 0.
    for e in engine_list {
        if e:ignition {
            set f to f + e:availablethrust.
        }
    }
    return f.
}

function ap_orb_nav_do {
    parameter vel_vec is AP_NAV_VEL. // defaults are globals defined in AP_NAV
    parameter acc_vec is AP_NAV_ACC.
    parameter head_dir is AP_NAV_ATT.

    if AP_NAV_IN_SURFACE {
        set delta_v to (vel_vec - ship:velocity:surface).
        set delta_a to (acc_vec - GRAV_ACC).
        set alpha_c to sat( W_A*(delta_a + 0.5*delta_v)*ship:facing:topvector*ship:mass/ship:q , 10 ).
        set beta_c to sat( W_A*(delta_a + 0.5*delta_v)*ship:facing:starvector*ship:mass/ship:q , 10 ).
        util_hud_push_right("ap_orb_nav_do_in_surface", "ac/bc: " + round_dec(alpha_c,2) + "," + round_dec(beta_c,2)).
    } else {
        set delta_v to (vel_vec - ship:velocity:orbit).
        set delta_a to (acc_vec - GRAV_ACC).
    }
    

    if not SAS {
        ap_orb_lock_controls(true).
        
        local have_thrust is (orb_thrust() > 0).

        if not DO_BURN and have_thrust and ((delta_v:mag > RCS_MAX_DV) or
            (not USE_RCS and delta_v:mag > 0.05)) {
            set BURNvec to delta_v:normalized.
            set DO_BURN to true.
        } else if DO_BURN and (not have_thrust or BURNvec*delta_v < 0.05) {
            set DO_BURN to false.
        }
        if DO_BURN and (ship:facing*ENGINE_VEC)*BURNvec > 0.95 and omega:mag < 0.1 {
            set orb_throttle to K_ORB_ENGINE_FORE*(ship:facing*ENGINE_VEC)*delta_v.
        } else {
            set orb_throttle to 0.0.
        }

        if AP_NAV_IN_SURFACE {
            set orb_steer_direction to srf_head_from_vec(vel_vec)*R(-alpha_c,beta_c,0).
        } else if DO_BURN {
            set orb_steer_direction to BURNvec:direction.
        } else {
            set orb_steer_direction to head_dir.
        }
        local head_error is (-ship:facing)*orb_steer_direction.
        set total_head_align to 0.5*head_error:forevector*V(0,0,1) + 0.5*head_error:starvector*V(1,0,0).
        
        local STEER_RCS is not AP_NAV_IN_SURFACE and USE_RCS_STEER and (total_head_align < MIN_ALIGN).
        local MOVE_RCS is not AP_NAV_IN_SURFACE and (total_head_align >= RCS_MIN_ALIGN
                and (delta_v:mag > 0.0005 and (delta_v:mag < RCS_MAX_DV or not have_thrust))).
        
        if RCSon and (throttle > 0.0 or not ( STEER_RCS or MOVE_RCS)) {
            set RCSon to false.
        } else if not RCSon and throttle = 0 and (MOVE_RCS or STEER_RCS) {
            set RCSon to true.
        }
        set RCS to RCSon.
        util_hud_push_left("ap_orb_nav_do", (choose "R" if RCSon else "") +(choose "B" if MOVE_RCS else "") + (choose "S" if STEER_RCS else "") ).

        if RCSon and (total_head_align >= RCS_MIN_ALIGN) {
            set ship:control:translation to V(
                pwm_alivezone(K_RCS_STARBOARD*(ship:facing:starvector*delta_v) + ship:facing:starvector*acc_vec*MTR),
                pwm_alivezone(K_RCS_TOP*(ship:facing:topvector*delta_v) + ship:facing:topvector*acc_vec*MTR),
                pwm_alivezone(K_RCS_FORE*(ship:facing:forevector*delta_v) + ship:facing:forevector*acc_vec*MTR)).
        } else {
            set ship:control:translation to V(0,0,0).
        }
    } else {
        ap_orb_lock_controls(false).
    }
}

// to lock and unlock controls in the same place
function ap_orb_lock_controls {
    parameter do_lock.
    if do_lock {
        lock steering to orb_steer_direction.
        lock throttle to orb_throttle.
    } else {
        unlock throttle.
        unlock steering.
    }
}

function ap_orb_status_string {
    local hud_str is "".

    if (true) {
        set hud_str to hud_str + "align  " + round_dec(total_head_align,3) + char(10) + 
            "dv "  + round_dec(delta_v:mag,3) + char(10) + (choose "B" if DO_BURN else " ")
            + "(" + round_dec(ship:facing:starvector*delta_v,2) + "," +
                round_dec(ship:facing:topvector*delta_v,2) + "," +
                round_dec(ship:facing:forevector*delta_v,2) +")".
    }
    
    return hud_str.
}
