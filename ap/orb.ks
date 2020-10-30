
global AP_ORB_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_ORB", lexicon()).

local USE_RCS to get_param(PARAM, "USE_RCS", true).
local USE_RCS_STEER to get_param(PARAM, "USE_RCS_STEER", false).

local MIN_ALIGN is cos(get_param(PARAM, "STEER_MAX_ANGLE", 1.0)).

local K_RCS_STARBOARD is get_param(PARAM, "K_RCS_STARBOARD",1.0).
local K_RCS_TOP is get_param(PARAM, "K_RCS_TOP",1.0).
local K_RCS_FORE is get_param(PARAM, "K_RCS_FORE",1.0).
local K_ORB_ENGINE_FORE is get_param(PARAM, "K_ORB_ENGINE_FORE",0.5).

local RCS_MAX_DV is choose 0 if not USE_RCS else get_param(PARAM, "RCS_MAX_DV", 10.0).
local RCS_MIN_ALIGN is cos(get_param(PARAM, "RCS_MAX_ANGLE", 10.0)).

local MAX_STEER_TIME is get_param(PARAM, "MAX_STEER_TIME", 10.0).

local lock MTR to ship:mass/(RCSthrust).

local lock omega to RAD2DEG*ship:angularVel.

local lock ship_vel to (-SHIP:FACING)*ship:velocity:surface:direction.
local lock alpha to wrap_angle(ship_vel:pitch).
local lock beta to wrap_angle(-ship_vel:yaw).

local lock HAVE_FUEL to (ship:liquidfuel > 0.01).
local lock SRFV_MARGIN to (choose 200 if AP_NAV_IN_SURFACE else 0).

local orb_steer_direction is ship:facing.
local total_head_align is 0.

local DO_BURN is false.
local delta_v is V(0,0,0).
local delta_a is V(0,0,0).

local RCSon to false.

local alpha_c is 0.0.
local beta_c is 0.0.
local W_A is 0.8.


// local RCSthrust is -1.
// local RCSthrustvec is V(0,0,1).
local RCSTpos is V(-1,-1,-1). // not really a vector but a list of max
local RCSTneg is V(+1,+1,+1). // and min values in ship relative axes
local RCSIsp is -1.

local METvec is V(0,0,1).
local MEIsp is V(0,0,0).

local function init_orb_params {
    // RCS stuff
    set RCSTpos to V(0,0,0).
    set RCSTneg to V(0,0,0).
    for i in ship:parts {
        if i:name = "linearRCS" {
            local F is 2.0*((-ship:facing)*i:rotation):topvector*
                i:getmodule("ModuleRCSFX"):getfield("thrust limiter")/100.
            set RCSTpos to vec_max(RCSTpos,RCSTpos+F).
            set RCSTneg to vec_min(RCSTneg,RCSTneg+F).
        }
        if i:name = "vernierEngine" {
            local F is -12.0*((-ship:facing)*i:rotation):starvector.
            set RCSTpos to vec_max(RCSTpos,RCSTpos+F).
            set RCSTneg to vec_min(RCSTneg,RCSTneg+F).
        }
        if i:name = "RCSBlock.v2" {
            for angle in list(0,90,180,270) {
                local F is 1.0*((-ship:facing)*i:rotation*R(angle,0,0)):vector*
                    i:getmodule("ModuleRCSFX"):getfield("thrust limiter")/100.
                set RCSTpos to vec_max(RCSTpos,RCSTpos+F).
                set RCSTneg to vec_min(RCSTneg,RCSTneg+F).
            }
        }
    }
    set RCSIsp to 240.

    print "RCSdata" +
        char(10) +" s(" + round_dec(RCSTneg:x,2) + "," + round_dec(RCSTpos:x,2) + ")" +
        char(10) +" t(" + round_dec(RCSTneg:y,2) + "," + round_dec(RCSTpos:y,2) + ")" +
        char(10) +" f(" + round_dec(RCSTneg:z,2) + "," + round_dec(RCSTpos:z,2) + ")".

    // Main Engine Stuff
    list engines in engine_list.
    set METvec to V(0,0,0).
    set MEIsp to V(0,0,0).

    for e in engine_list {
        if e:ignition and e:availablethrust > 0 and e:isp > 0 {
            local evec is e:availablethrust*((-ship:facing)*e:facing:forevector).
            set METvec to METvec + evec.
            set MEIsp to MEIsp + evec/e:isp.
        }
    }
    if MEIsp:x > 0.0001 { set MEIsp:x to METvec:x/MEIsp:x. }
    if MEIsp:y > 0.0001 { set MEIsp:y to METvec:y/MEIsp:y. }
    if MEIsp:z > 0.0001 { set MEIsp:z to METvec:z/MEIsp:z. }

    print "ME data" +
        char(10) +"F (" + round_dec(METvec:x,2) + "," + round_dec(METvec:y,2) + "," + round_dec(METvec:z,2) + ")" +
        char(10) +"Isp (" + round_dec(MEIsp:x,2) + "," + round_dec(MEIsp:y,2) + "," + round_dec(MEIsp:z,2) + ")".

    // Steering Manager Stuff
    // STEERINGMANAGER:RESETTODEFAULT().
    // STEERINGMANAGER:RESETPIDS().
    set STEERINGMANAGER:PITCHPID:KP to get_param(PARAM, "P_KP", 8.0).
    set STEERINGMANAGER:PITCHPID:KI to get_param(PARAM, "P_KI", 8.0).
    set STEERINGMANAGER:PITCHPID:KD to get_param(PARAM, "P_KD", 12.0).

    set STEERINGMANAGER:YAWPID:KP to get_param(PARAM, "Y_KP", 8.0).
    set STEERINGMANAGER:YAWPID:KI to get_param(PARAM, "Y_KI", 8.0).
    set STEERINGMANAGER:YAWPID:KD to get_param(PARAM, "Y_KD", 12.0).

    set STEERINGMANAGER:ROLLPID:KP to get_param(PARAM, "R_KP", 8.0).
    set STEERINGMANAGER:ROLLPID:KI to get_param(PARAM, "R_KI", 8.0).
    set STEERINGMANAGER:ROLLPID:KD to get_param(PARAM, "R_KD", 12.0).

    set STEERINGMANAGER:MAXSTOPPINGTIME to 2.0.

    if defined AP_NAV_ENABLED and AP_NAV_IN_SURFACE {
        set STEERINGMANAGER:ROLLCONTROLANGLERANGE to 180.
    }
    print "orb gains " + STEERINGMANAGER:PITCHPID:KP + " "
                        + STEERINGMANAGER:PITCHPID:KI + " "
                        + STEERINGMANAGER:PITCHPID:KD.
}

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

local function max_dir {
    parameter v_in.
    parameter poslim_vec.
    parameter neglim_vec.

    local dzone is 0.01.

    local v_out is V(0,0,0).
    set v_out:x to (choose poslim_vec:x if v_in:x > dzone else 0) + (choose neglim_vec:x if v_in:x < -dzone else 0).
    set v_out:y to (choose poslim_vec:y if v_in:y > dzone else 0) + (choose neglim_vec:y if v_in:y < -dzone else 0).
    set v_out:z to (choose poslim_vec:z if v_in:z > dzone else 0) + (choose neglim_vec:z if v_in:z < -dzone else 0).

    return v_out.
}

// return if orb engine is usable
local function orb_thrust {
    list engines in engine_list.
    local f is 0. // engine thrust (1000 kg * m/s²) (kN)
    for e in engine_list {
        if e:ignition {
            set f to f + e:availablethrust.
        }
    }
    return f.
}

// returns -1 if maneuver is not possible given fuel/thrust etc
//  time in seconds if maneuver possible in the given thrust vector
local last_delta_v is V(-1,-1,-1).
local last_thrust_vector is V(-1,-1,-1).
local last_mass is ship:mass.
local last_controlpart is ship:controlpart.
local last_stage is -2.
local last_time is -1.
function ap_orb_maneuver_time {
    parameter delta_v.
    parameter thrust_vector is V(0,0,1).
    if ship:mass = last_mass and
        (last_delta_v-delta_v):mag < 0.03 and
        (last_thrust_vector-thrust_vector):mag < 0.001 and 
        ship:controlpart = last_controlpart and
        stage:number = last_stage {
        return last_time.
    }

    if ship:controlpart <> last_controlpart or
        stage:number <> last_stage {
        init_orb_params().
    }

    local m_engine_prop is 0.
    local m_rcs_prop is 0.
    for r in ship:resources {
        if r:name = "LiquidFuel" or r:name = "Oxidizer" {
            set m_engine_prop to m_engine_prop + r:amount*r:density.
        } else if r:name = "Monopropellant" {
            set m_rcs_prop to m_rcs_prop + r:amount*r:density.
        }
    }

    local RCSThrust is max_dir(thrust_vector, RCSTpos, RCSTneg):mag.
    local METhrust is METvec*(thrust_vector:normalized).
    // print "RCS thrust : " + round_dec(RCSThrust,3).
    // print "ME thrust : " + round_dec(METhrust,3).
    if METhrust < RCSThrust {
        set m_engine_prop to 0.
    }

    local v_e is g0*MEIsp*(thrust_vector:normalized).
    local v_e_rcs is g0*RCSIsp.

    local m_me_burn is ship:mass+1.
    if v_e > 0 {
        set m_me_burn to ship:mass*(1 - constant():e^(-delta_v:mag/(v_e))).
    }

    if m_me_burn < m_engine_prop {
        set last_time to (v_e/METhrust) *m_me_burn. // F = m vdot = -mdot ve -> v_e/f = mdot
    } else {
        local m_engine_delta_v is v_e*ln(ship:mass/(ship:mass-m_engine_prop)).
        local m_rcs_burn is (ship:mass-m_engine_prop)*
                        (1 - constant():e^(-(delta_v:mag-m_engine_delta_v)/(v_e_rcs))).

        if (m_rcs_burn) < m_rcs_prop {
            local me_time is choose (v_e/METhrust) *m_engine_prop if METhrust > 0 else 0.
            set last_time to me_time + (v_e_rcs/RCSThrust) *(m_rcs_burn).
        } else {
            set last_time to -1.
        }
    }
    set last_mass to ship:mass.
    set last_delta_v to delta_v.
    set last_thrust_vector to thrust_vector.
    set last_controlpart to ship:controlpart.
    set last_stage to stage:number.
    return last_time.
}

function ap_orb_steer_time {
    parameter steer_to_vector.
    return MAX_STEER_TIME.
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
    } else {
        set delta_v to (vel_vec - ship:velocity:orbit).
        set delta_a to (acc_vec - GRAV_ACC).
    }
    

    if not SAS {
        ap_orb_lock_controls(true).
        
        local me_delta_v is 0.
        if METvec:mag > 0 {
            set me_delta_v to (ship:facing*METvec:normalized)*delta_v.
        }
        if not DO_BURN and me_delta_v > RCS_MAX_DV {
            set DO_BURN to true.
        } else if DO_BURN and me_delta_v <= 0 {
            set DO_BURN to false.
        } 
        set ship:control:mainthrottle to choose K_ORB_ENGINE_FORE*me_delta_v if DO_BURN else 0.

        if AP_NAV_IN_SURFACE {
            set orb_steer_direction to srf_head_from_vec(vel_vec)*R(-alpha,0,0).
            // util_hud_push_right("ap_orb_nav_do_in_surface", "a/b: " + round_dec(alpha,2) + "," + round_dec(beta,2)).
            // set orb_srf_steer_vector to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,0,1),
                // "", 3.0, true, 1.0, true ).
            // set orb_srf_steer_vector:vec to 30*orb_steer_direction:starvector.
            // set orb_srf_steer_vector:vec to 30*AP_NAV_VEL.
            // set orb_srf_steer_vector:show to true.
        } else {
            set orb_steer_direction to head_dir.
        }
        local head_error is (-ship:facing)*orb_steer_direction.
        set total_head_align to 0.5*head_error:forevector*V(0,0,1) + 0.5*head_error:starvector*V(1,0,0).
        
        local STEER_RCS is not AP_NAV_IN_SURFACE and USE_RCS_STEER and (total_head_align < MIN_ALIGN).
        local MOVE_RCS is not DO_BURN and (total_head_align >= RCS_MIN_ALIGN and delta_v:mag > 0.0005).
        
        if RCSon and (throttle > 0.0 or not ( STEER_RCS or MOVE_RCS)) {
            set RCSon to false.
        } else if not RCSon and throttle = 0 and (MOVE_RCS or STEER_RCS) {
            set RCSon to true.
        }
        set RCS to RCSon.
        if defined UTIL_HUD_ENABLED {
            util_hud_push_left("ap_orb_nav_do", (choose "R" if RCSon else "") +(choose "B" if MOVE_RCS else "") + (choose "S" if STEER_RCS else "") ).
        }

        if RCSon and (total_head_align >= RCS_MIN_ALIGN) {
            local saturated_delta_v is delta_v:normalized*min(delta_v:mag,RCS_MAX_DV).
            set ship:control:translation to V(
                pwm_alivezone(K_RCS_STARBOARD*(ship:facing:starvector*saturated_delta_v) ),
                pwm_alivezone(K_RCS_TOP*(ship:facing:topvector*saturated_delta_v) ),
                pwm_alivezone(K_RCS_FORE*(ship:facing:forevector*saturated_delta_v) )).
        } else {
            set ship:control:translation to V(0,0,0).
        }
    } else {
        ap_orb_lock_controls(false).
    }
}

// to lock and unlock controls in the same place
local controls_locked is false.
function ap_orb_lock_controls {
    parameter do_lock.
    if (do_lock = controls_locked) {
        return.
    } else if do_lock {
        init_orb_params().
        lock steering to orb_steer_direction.
        set controls_locked to true.
        print "ap_orb_lock_controls: locked".
    } else {
        unlock steering.
        set controls_locked to false.
        print "ap_orb_lock_controls: unlocked".
    }
}

function ap_orb_status_string {
    local hud_str is "".

    if (true) {
        set hud_str to hud_str + "align  " + round_dec(total_head_align,3) + char(10) + 
            "dv "  + round_dec(delta_v:mag,3) + char(10) + (choose "B" if DO_BURN else " ")
            + "(" + round_dec(ship:facing:starvector*delta_v,2) + "," +
                round_dec(ship:facing:topvector*delta_v,2) + "," +
                round_dec(ship:facing:forevector*delta_v,2) +")" + char(10) + 
                "G "+ round_dec( get_applied_acc()*ship:facing:vector/g0, 1).
    }
    
    return hud_str.
}
