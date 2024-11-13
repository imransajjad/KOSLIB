
global AP_ORB_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_ORB", lexicon()).

local KP is get_param(PARAM, "R_KP", 20.0).
local KI is get_param(PARAM, "R_KI", 100.0).
local KD is get_param(PARAM, "R_KD", 0.0).

// rate PID gains
local pratePID is PIDLOOP(
    get_param(PARAM, "PR_KP", KP),
    get_param(PARAM, "PR_KI", KI),
    get_param(PARAM, "PR_KD", KD),
    -1.0,1.0).

local yratePID is PIDLOOP(
    get_param(PARAM, "YR_KP", KP),
    get_param(PARAM, "YR_KI", KI),
    get_param(PARAM, "YR_KD", KD),
    -1.0,1.0).

local rratePID is PIDLOOP(
    get_param(PARAM, "RR_KP", KP),
    get_param(PARAM, "RR_KI", KI),
    get_param(PARAM, "RR_KD", KD),
    -1.0,1.0).

local MIN_SEA_Q is 1.0*(10/420)^2.
local HAVE_FINS is get_param(PARAM,"HAVE_FINS", false).

local CORNER_VELOCITY is get_param(PARAM,"CORNER_VELOCITY", 200).
local MAXG is get_param(PARAM,"MAXG", 10)*g0.


// USES AG6

local lock AG to AG6.

// nav angle difference gains
local K_PITCH is get_param(PARAM,"K_PITCH", 0.5).
local K_YAW is get_param(PARAM,"K_YAW", 0.5).
local K_ROLL is get_param(PARAM,"K_ROLL", 1.0).


local USE_RCS to get_param(PARAM, "USE_RCS", true).
local USE_RCS_STEER to get_param(PARAM, "USE_RCS_STEER", false).

local K_TRANS is get_param(PARAM, "K_TRANS",1.0).
local K_RCS_STARBOARD is get_param(PARAM, "K_RCS_STARBOARD",K_TRANS).
local K_RCS_TOP is get_param(PARAM, "K_RCS_TOP",K_TRANS).
local K_RCS_FORE is get_param(PARAM, "K_RCS_FORE",K_TRANS).
local K_ORB_ENGINE_FORE is get_param(PARAM, "K_ORB_ENGINE_FORE",K_TRANS).

local K_AERO_PITCH is get_param(PARAM,"K_AERO_PITCH", 0.5).

local RCS_MAX_DV is choose 0 if not USE_RCS else get_param(PARAM, "RCS_MAX_DV", 10.0).
local RCS_MIN_ALIGN is cos(get_param(PARAM, "RCS_MAX_ANGLE", 2.0)).

local MAX_STEER_TIME is get_param(PARAM, "MAX_STEER_TIME", 10.0).

// local orb_steer_direction is ship:facing.

local ALIGNED is true.
local DO_BURN is false.
local AERO_Q is false.
local STEER_RCS is false.
local MOVE_RCS is false.
local GLIM is false.

local RCSTpos is V(0,0,0). // not really a vector but a list of max
local RCSTneg is V(0,0,0). // and min values in ship relative axes
local RCSIsp is V(1,1,1).
local last_rcs_list is list().
local function ap_orb_get_rcs_params {
    // RCS stuff
    set last_rcs_list to ship:rcs:copy().
    set RCSTpos to V(0,0,0).
    set RCSTneg to V(0,0,0).

    for i in ship:rcs {
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
    set RCSIsp to 240*V(1,1,1).

    print "RCSdata" +
        " s(" + round_dec(RCSTneg:x,2) + "," + round_dec(RCSTpos:x,2) + ")" +
        " t(" + round_dec(RCSTneg:y,2) + "," + round_dec(RCSTpos:y,2) + ")" +
        " f(" + round_dec(RCSTneg:z,2) + "," + round_dec(RCSTpos:z,2) + ")".
}

function ap_orb_get_rcs_isp {
    if (last_rcs_list:length <> ship:rcs:length ) {
        ap_orb_get_rcs_params().
    }
    return RCSIsp.
}

function ap_orb_get_rcs_pthrust {
    if (last_rcs_list:length <> ship:rcs:length ) {
        ap_orb_get_rcs_params().
    }
    return RCSTpos.
}

function ap_orb_get_rcs_nthrust {
    if (last_rcs_list:length <> ship:rcs:length ) {
        ap_orb_get_rcs_params().
    }
    return RCSTneg.
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

// get the current maximum angular velocity allowed in rad/s
local function get_max_rrates {

    if ship:q < MIN_SEA_Q {
        return V(90,90,360)*DEG2RAD.
    }
    else
    {
        local min_rate is 2.5*DEG2RAD.

        local corner_sea_q is 1.0*(CORNER_VELOCITY/420)^2.
        local corner_cl is cl_sched(CORNER_VELOCITY).

        local fake_wing_area is (MAXG)/(corner_sea_q*corner_cl)*(ship:drymass).
        local loadfactor is ship:q*cl_sched(ship:airspeed)/ship:mass.

        set GLIM to (loadfactor*fake_wing_area > MAXG).

        if GLIM {
            local prate_max is max(min_rate, (MAXG - g0*cos(vel_pitch)*cos(roll))/ship:airspeed ).
            local yrate_max is max(min_rate, MAXG/ship:airspeed ).
            local rrate_max is 5.0*max(min_rate, MAXG/ship:airspeed ).
            return V(prate_max, yrate_max, rrate_max).
        } else {
            local prate_max is max(30*DEG2RAD, (loadfactor*fake_wing_area - g0*cos(vel_pitch)*cos(roll))/ship:airspeed ).
            local yrate_max is max(30*DEG2RAD, loadfactor*fake_wing_area/ship:airspeed ).
            local rrate_max is 5.0*max(30*DEG2RAD, loadfactor*fake_wing_area/ship:airspeed ).
            return V(prate_max, yrate_max, rrate_max).
        }

    }
}

local function control_aalpha {
    return V(0,0,0).
}

local ship_num_parts is 0.
local reaction_wheel_torque is V(0,0,0).
local function get_reaction_wheel_torque {
    if ship_num_parts = ship:parts:length {
        return reaction_wheel_torque.
    }
    set ship_num_parts to ship:parts:length.
    set reaction_wheel_torque to V(0,0,0).

    for pt in ship:parts {
        if pt:hasmodule("ModuleReactionWheel") {
            print "found " + pt.
            if pt:name:startswith("mk1-3pod") {
                print "adding mk1-3pod torque".
                set reaction_wheel_torque to reaction_wheel_torque + V(15,15,15).
            } else if pt:name = "sasModule" {
                set reaction_wheel_torque to reaction_wheel_torque + V(5,5,5).
            }  else if pt:name = "asasmodule1-2" {
                set reaction_wheel_torque to reaction_wheel_torque + V(30,30,30).
            }  else if pt:name = "advSasModule" {
                set reaction_wheel_torque to reaction_wheel_torque + V(15,15,15).
            }
        }
    }
    return reaction_wheel_torque.
}

function ap_get_control_bu {

    local B is V(0.0,0.0,0.0).

    if HAVE_FINS {
        local alsat is sat(alpha,35).
        set B:x to B:x + 350.0*(max(ship:q,MIN_SEA_Q)*cl_sched(max(50,vel))*(cos(alsat)^3 - 1*cos(alsat)*sin(alsat)^2)+
            cd_sched(max(50,vel))*(2*cos(alsat)*sin(alsat)^2)).
        
        local besat is sat(beta,35).
        set B:y to B:y + 350.0*(max(ship:q,MIN_SEA_Q)*cl_sched(max(50,vel))*(cos(besat)^3 - 1*cos(besat)*sin(besat)^2)+
            cd_sched(max(50,vel))*(2*cos(besat)*sin(besat)^2)).
        
        set B:z to B:z + (B:x + B:y)/3.
    }
    set B to B + get_reaction_wheel_torque().
    
    if ( true) { // q debug
        util_hud_push_left("orb_ap_get_control_bu", 
            char(10) + "q " + round_dec(ship:q,7) +
            char(10) + "B_ux " + round_fig(B:x,3) +
            char(10) + "B_uy " + round_fig(B:y,3) +
            char(10) + "B_uz " + round_fig(B:z,3)).
    }
    return B.
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

    local m_engine_prop is 0.
    local m_rcs_prop is 0.
    for r in ship:resources {
        if r:name = "LiquidFuel" or r:name = "Oxidizer" {
            set m_engine_prop to m_engine_prop + r:amount*r:density.
        } else if r:name = "Monopropellant" {
            set m_rcs_prop to m_rcs_prop + r:amount*r:density.
        }
    }
    local rcs_upper is ap_orb_get_rcs_pthrust().
    local rcs_lower is ap_orb_get_rcs_nthrust().
    local rcs_isp is ap_orb_get_rcs_isp().
    local RCSThrust is max_dir(thrust_vector, rcs_upper, rcs_lower):mag.

    local me_upper is ap_me_get_thrust().
    local me_isp is ap_me_get_isp().
    local METhrust is me_upper*(thrust_vector:normalized).

    if METhrust < RCSThrust or delta_v:mag <= RCS_MAX_DV {
        set m_engine_prop to 0. // only use rcs for this maneuver
    }

    local v_e is g0*me_isp*(thrust_vector:normalized).
    local v_e_rcs is g0*rcs_isp*(thrust_vector:normalized).

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
    parameter steer_to_attitude.
    return MAX_STEER_TIME.
}

function ap_orb_rcs_dv {
    return RCS_MAX_DV.
}

function ap_orb_nav_do {
    parameter vel_vec is AP_NAV_VEL. // defaults are globals defined in AP_NAV
    parameter acc_vec is AP_NAV_ACC.
    parameter head_dir is AP_NAV_ATT.

    // only once vel and acc are okay then we move to att

    local delta_v is (vel_vec - ap_nav_get_vessel_vel()).
    local delta_a is (acc_vec - GRAV_ACC).

    if not SAS {

        // decide if we want to use the main engine and adjust orientation accordingly
        local thrust_vector is ap_me_get_thrust().
        local me_delta_v is (ship:facing*thrust_vector:normalized)*delta_v.
        local me_align is me_delta_v/max(0.0001,delta_v:mag).

        local turn_to_engine is false.
        
        if thrust_vector:mag > 0 and delta_v:mag > 0 {
            // 
            local omega is -1*vcrs(delta_v:normalized, ship:facing*thrust_vector:normalized).
            local omega_mag is vectorAngle(delta_v:normalized, ship:facing*thrust_vector:normalized).
            set head_dir to angleaxis( omega_mag, omega:normalized )*ship:facing.
            set turn_to_engine to true.
        }
        local me_throttle is choose K_ORB_ENGINE_FORE*me_delta_v if (me_align > 0.9848) else 0.
        // get me_throttle

        // dv_aero is part of delta_v that can be "steered" by aero  
        local dv_aero is vectorexclude(ship:velocity:surface, delta_v).
        local D is abs(ship:q*get_wing_area()*cl_sched(ship:airspeed)*cos(2*alpha)*cos(2*beta)/ship:mass/ship:airspeed).
        local D_a is abs(ship:q*get_wing_area()*cl_sched(ship:airspeed)/ship:mass).

        local a_applied is D_a*(cos(alpha)*sin(alpha)*ship_vel_dir:topvector + cos(beta)*sin(beta)*ship_vel_dir:starvector).

        local vw is K_AERO_PITCH*(dv_aero - a_applied/max(0.05,D)) + GRAV_ACC.
        local w_v is (-ship:facing)*vcrs(ship:velocity:surface:normalized, vw)/max(0.001,ship:airspeed)*RAD2DEG.
        // get w_v

        // use head_error to figure out how much to turn for orientation
        local head_error is (-ship:facing)*head_dir.
        set total_head_align to 0.5*head_error:forevector*V(0,0,1) + 0.5*head_error:starvector*V(1,0,0).
        set ALIGNED to total_head_align >= RCS_MIN_ALIGN.
        local w_head is V(K_PITCH*wrap_angle(head_error:pitch), K_YAW*wrap_angle(head_error:yaw),0).
        // ignore roll first
        set w_head:z to choose K_ROLL*wrap_angle(head_error:roll) if w_head:mag < 2.5 else 0.
        // get w_head

        // decide what can be done with rcs
        // local rcs_dv is delta_v:normalized*min(delta_v:mag,RCS_MAX_DV).
        local rcs_dv is delta_v.

        if me_throttle > 0 {
            set rcs_dv to vectorexclude(ap_me_get_thrust(), rcs_dv).
        }
        local rcs_move is V(
                pwm_alivezone(K_RCS_STARBOARD*(ship:facing:starvector*rcs_dv) ),
                pwm_alivezone(K_RCS_TOP*(ship:facing:topvector*rcs_dv) ),
                pwm_alivezone(K_RCS_FORE*(ship:facing:forevector*rcs_dv) )).



        // now use me_throttle, w_v, w_head, rcs_move
        local w_error is choose w_head if turn_to_engine else w_v.

        local min_dv is RCS_MAX_DV.
        if (ship:control:mainthrottle > 0) {
            set min_dv to 0.01*RCS_MAX_DV. // add some hysteresis
        }
        if delta_v:mag > min_dv and ship:availablethrust > 0 {
            ap_me_throttle(me_throttle).
        } else {
            ap_me_throttle(0).
        }
        ap_orb_w(-w_error:x, w_error:y, -w_error:z, true).
        set ship:control:translation to rcs_move.

        set STEER_RCS to USE_RCS_STEER and not ALIGNED.        
        set RCS to (rcs_move:mag > 0 or STEER_RCS).

        set last_stage to stage:number.

        if (false) {
            util_hud_push_left( "ap_orb_nav_do",
                "|dv| "  + round_dec(delta_v:mag,1) 
                + char(10) + "dv " + round_vec((-ship:facing)*delta_v,1)
                + char(10) + "w_v " + round_vec(w_v,1)
                + char(10) + "w_h " + round_vec(w_head,1)
                + char(10) + "D " + round_fig(D,3)
                ).
            set orb_debug_vec0 to VECDRAW(V(0,0,0), (min(delta_v:mag,10)*delta_v:normalized), RGB(0,1,0),
                "", 1.0, true, 0.25, true ).
            set orb_debug_vec1 to VECDRAW(V(0,0,0), (ship:facing*w_v), RGB(0,1,1),
                "", 1.0, true, 0.25, true ).
            set orb_debug_vec2 to VECDRAW(V(0,0,0), a_applied, RGB(1,0,0),
                "", 1.0, true, 0.25, true ).
            set orb_debug_vec3 to VECDRAW(V(0,0,0), (ship:facing*w_head), RGB(1,0,1),
                "", 1.0, true, 0.25, true ).
        }
    }
}

function ap_orb_status_string {
    return "G"+ (choose "L " if GLIM else " ") +
        round_dec( get_max_applied_acc()/g0, 1) +
        (choose "A" if not ALIGNED else "") +
        (choose "Q" if AERO_Q else "") +
        (choose "M" if MOVE_RCS else "") +
        (choose "S" if STEER_RCS else "") +
        (choose "B" if DO_BURN else "").
}


local orb_active is true.
function ap_orb_w {
    parameter u1 is SHIP:CONTROL:PILOTPITCH. // pitch
    parameter u2 is SHIP:CONTROL:PILOTYAW. // yaw
    parameter u3 is SHIP:CONTROL:PILOTROLL. // roll
    parameter direct_mode is false.
    // in direct_mode, u1,u2,u3 are expected to be direct deg/s values
    // else they are stick inputs
    // now in ship velocity frame

    if SAS {
        if orb_active {
            set orb_active to false.
            rratePID:RESET().
            yratePID:RESET().
            pratePID:RESET().
            set SHIP:CONTROL:NEUTRALIZE to true.
        }
    }
    else
    {
        set orb_active to true.

        local omega is (-ship:facing)*ship:angularvel.

        local MOI is get_moment_of_inertia().
        local B is ap_get_control_bu().
        local A is control_aalpha() + 0*vcrs( omega, V(MOI:x*omega:x,MOI:y*omega:y,MOI:z*omega:z) ).

        local wmax is get_max_rrates().

        if direct_mode {
            set pratePID:SETPOINT to -sat(DEG2RAD*u1,wmax:x).
            set yratePID:SETPOINT to sat(DEG2RAD*u2,wmax:y).
            set rratePID:SETPOINT to -sat(DEG2RAD*u3,wmax:z).
        } else {
            local omega_v is ap_stick_w(u1,u2,u3).
            set pratePID:SETPOINT to -omega_v:x*wmax:x.
            set yratePID:SETPOINT to omega_v:y*wmax:y.
            set rratePID:SETPOINT to -omega_v:z*wmax:z.
        }



        local AG_warp is (choose 0.33 if AG else 1.0)/kuniverse:timewarp:rate.

        set pratePID:minoutput to -B:x/AG_warp/MOI:x.
        set pratePID:maxoutput to B:x/AG_warp/MOI:x.
        set yratePID:minoutput to -B:y/AG_warp/MOI:y.
        set yratePID:maxoutput to B:y/AG_warp/MOI:y.
        set rratePID:minoutput to -B:z/AG_warp/MOI:z.
        set rratePID:maxoutput to B:z/AG_warp/MOI:z.

        set SHIP:CONTROL:PITCH to -(MOI:x*pratePID:update(time:seconds, omega:x) + A:x)/B:x*AG_warp.
        set SHIP:CONTROL:YAW to (MOI:y*yratePID:update(time:seconds, omega:y) + A:y)/B:y*AG_warp.
        set SHIP:CONTROL:ROLL to -(MOI:z*rratePID:update(time:seconds, omega:z) + A:z)/B:z*AG_warp.


        
        if (true) { // pitch debug
            util_hud_push_left( "ap_orb_wx",
                char(10) + "ppid" + " " + round_dec(pratePID:KP,2) + " " + round_dec(pratePID:KI,2) + " " + round_dec(pratePID:KD,2) +
                char(10) + "pask" + " " + round_dec(RAD2DEG*pratePID:SETPOINT,1) + "/" + round_dec(RAD2DEG*wmax:x,1) +
                char(10) + "pact" + " " + round_dec(RAD2DEG*omega:x,1) +
                char(10) + "perr" + " " + round_fig(RAD2DEG*pratePID:ERROR,1)).
        }
        if (false) { // yaw debug
            util_hud_push_left( "ap_orb_wy",
                char(10) + "ypid" + " " + round_dec(yratePID:KP,2) + " " + round_dec(yratePID:KI,2) + " " + round_dec(yratePID:KD,2) +
                char(10) + "yask" + " " + round_dec(RAD2DEG*yratePID:SETPOINT,1) + "/" + round_dec(RAD2DEG*wmax:y,1) +
                char(10) + "yact" + " " + round_dec(RAD2DEG*omega:y,1) +
                char(10) + "yerr" + " " + round_fig(RAD2DEG*yratePID:ERROR,1) ).
        }
        if (false) { // roll debug
            util_hud_push_left( "ap_orb_wz",
                char(10) + "rpid" + " " + round_dec(rratePID:KP,2) + " " + round_dec(rratePID:KI,2) + " " + round_dec(rratePID:KD,2) +
                char(10) + "rask" + " " + round_dec(RAD2DEG*rratePID:SETPOINT,1) + "/" + round_dec(RAD2DEG*wmax:z,1) +
                char(10) + "ract" + " " + round_dec(RAD2DEG*omega:z,1) +
                char(10) + "rerr" + " " + round_fig(RAD2DEG*rratePID:ERROR,1) +
                char(10) + "rout" + " " + round_fig(rratePID:output,1) ).
        }
        if (false) { // moment debug
            util_hud_push_left( "ap_orb_mom",
                char(10) + "mom:x " + round_fig(ship:control:pilotmainthrottle*ap_me_get_mom():x,3) +
                char(10) + "mom:y " + round_fig(ship:control:pilotmainthrottle*ap_me_get_mom():y,3) +
                char(10) + "mom:z " + round_fig(ship:control:pilotmainthrottle*ap_me_get_mom():z,3) +
                char(10) + "ctrl:x " + round_fig(ship:control:pitch,3) +
                char(10) + "ctrl:y " + round_fig(ship:control:yaw,3) +
                char(10) + "ctrl:z " + round_fig(ship:control:roll,3)
                ).
        }
    }
}
