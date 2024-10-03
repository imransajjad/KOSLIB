
global AP_ORB_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_ORB", lexicon()).

local R_K is get_param(PARAM, "R_K", 3.0).
local R_theta is get_param(PARAM, "R_theta", 2.25).
local KP is R_K.
local KI is R_K/4*(R_K + tan(90-R_theta)^2).
local KD is 0.0.

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

local MIN_SEA_Q is 1.0*(50/420)^2.
local HAVE_FINS is get_param(PARAM,"HAVE_FINS", false).


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

local RCSTpos is V(-1,-1,-1). // not really a vector but a list of max
local RCSTneg is V(+1,+1,+1). // and min values in ship relative axes
local RCSIsp is -1.
local last_rcs_list is list().
function ap_orb_get_rcs_params {
    // RCS stuff
    set RCSTpos to V(0,0,0).
    set RCSTneg to V(0,0,0).

    if (last_rcs_list:length <> ship:rcs:length ) {
        set last_rcs_list to list(ship:rcs).
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
        set RCSIsp to 240.

        print "RCSdata" +
            " s(" + round_dec(RCSTneg:x,2) + "," + round_dec(RCSTpos:x,2) + ")" +
            " t(" + round_dec(RCSTneg:y,2) + "," + round_dec(RCSTpos:y,2) + ")" +
            " f(" + round_dec(RCSTneg:z,2) + "," + round_dec(RCSTpos:z,2) + ")".
    }

    return list(RCSTpos, RCSTneg, RCSIsp).
}

local METvec is V(0,0,1). // is a vector
local MEIsp is V(0,0,0). // is also a vector is exhaust velocity in multiple directions
local last_available_thrust is -1.
local function ap_orb_me_params {
    // Main Engine Stuff
    // return the ME thrust vector and the Isp vector
    set last_available_thrust to ship:availablethrust.
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
}

function ap_orb_get_me_thrust
{
    if ( abs(ship:availablethrust - last_available_thrust) > 0.25) {
        ap_orb_me_params().
    }
    return METvec.
}

function ap_orb_get_me_isp
{
    if ( abs(ship:availablethrust - last_available_thrust) > 0.25) {
        ap_orb_me_params().
    }
    return MEIsp.
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

local function control_aalpha {
    return V(0,0,0).
}

local function control_bu {

    local B_ux is 1.0.
    local B_uy is 1.0.
    local B_uz is 1.0.

    if HAVE_FINS {
        local alsat is sat(alpha,35).
        set B_ux to  0.1*(max(ship:q,MIN_SEA_Q)*cl_sched(max(50,vel))*(cos(alsat)^3 - 1*cos(alsat)*sin(alsat)^2)+
            cd_sched(max(50,vel))*(2*cos(alsat)*sin(alsat)^2)).
        
        local besat is sat(beta,35).
        set B_uy to  0.1*(max(ship:q,MIN_SEA_Q)*cl_sched(max(50,vel))*(cos(besat)^3 - 1*cos(besat)*sin(besat)^2)+
            cd_sched(max(50,vel))*(2*cos(besat)*sin(besat)^2)).
        
        set B_uz to (B_ux + B_ux)/3.

    } else {
        set B_ux to 5/20. // nominal value to match params
        set B_uy to 5/20. // nominal value to match params
        set B_uz to 5/20. // nominal value to match params
    }

    if ( true) { // q debug
        util_hud_push_left("orb_control_bu", 
            char(10) + "q " + round_dec(ship:q,7) +
            char(10) + "B_ux " + round_fig(B_ux,3) +
            char(10) + "B_uy " + round_fig(B_uy,3) +
            char(10) + "B_uz " + round_fig(B_uz,3)).
    }
    return V(B_ux, B_uy, B_uz).
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
    local rcsdata is ap_orb_get_rcs_params().
    local rcs_upper is rcsdata[0].
    local rcs_lower is rcsdata[1].
    local rcs_isp is rcsdata[2].
    local RCSThrust is max_dir(thrust_vector, rcs_upper, rcs_lower):mag.

    local me_data is ap_orb_get_me_params().
    local me_upper is me_data[0].
    local me_isp is me_data[1].
    local METhrust is me_upper*(thrust_vector:normalized).

    if METhrust < RCSThrust or delta_v:mag <= RCS_MAX_DV {
        set m_engine_prop to 0. // only use rcs for this maneuver
    }

    local v_e is g0*me_isp*(thrust_vector:normalized).
    local v_e_rcs is g0*rcs_isp.

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

        // decide if we want to use the main engine and adjust accordingly
        local thrust_vector is ap_orb_get_me_thrust().
        local me_delta_v is (ship:facing*thrust_vector:normalized)*delta_v.
        local me_align is me_delta_v/max(0.0001,delta_v:mag).

        // 
        local omega is -1*vcrs(delta_v:normalized, ship:facing*thrust_vector:normalized).
        local omega_mag is vectorAngle(delta_v:normalized, ship:facing*thrust_vector:normalized).
        set head_dir to angleaxis( omega_mag, omega:normalized )*ship:facing.

        local w_v is V(0,0,0).
        local g_max is sat( 100*ship:q/0.416, 100).
        local a_applied is (-ship_vel_dir)*(K_AERO_PITCH*delta_v + acc_vec).
        set a_applied:z to 0.
        set a_applied to min(g_max,a_applied:mag)*a_applied:normalized.
        set w_v to V(-a_applied:y,a_applied:x,0)/max(10,ship:velocity:orbit:mag)*RAD2DEG.

        local aero_convex is min(ship:mass*g_max/max(0.00001,thrust_vector:mag),1).

        set orb_debug_vec1 to VECDRAW(V(0,0,0), (ship_vel_dir*a_applied), RGB(0,0,1),
            "", 1.0, true, 0.25, true ).
        util_hud_push_left("ap_orb_nav_do_w", "w:" + round_vec(w_v,1) + char(10) + 
                                            "astr: " + round_vec(a_applied,1) + char(10) +
                                            "acvx: " + round(aero_convex,1) + char(10)).

        local min_dv is RCS_MAX_DV.
        if (ship:control:mainthrottle > 0) {
            set min_dv to 0.01*RCS_MAX_DV.
        }
        if delta_v:mag > min_dv and ship:availablethrust > 0 {
            set ship:control:mainthrottle to choose K_ORB_ENGINE_FORE*me_delta_v if (me_align > 0.9848) else 0.
            set DO_BURN to true.
        } else {
            set ship:control:mainthrottle to 0.
            set DO_BURN to false.
            
        }

        // decide if we want to use aero glide and adjust accordintly
        // local w_v is V(0,0,0).
        // set AERO_Q to false.
        // if not DO_BURN and ship:q > 0.013 {
        //     local a_applied is (-ship_vel_dir)*(K_AERO_PITCH*delta_v + acc_vec).
        //     set a_applied:z to 0.
        //     local g_max is sat( 100*ship:velocity:surface:mag/200, 100).
        //     set a_applied to min(g_max,a_applied:mag)*a_applied:normalized.
        //     set w_v to V(-a_applied:y,a_applied:x,0)/max(10,ship:velocity:surface:mag)*RAD2DEG.
            
        //     set orb_debug_vec1 to VECDRAW(V(0,0,0), (ship_vel_dir*a_applied), RGB(0,0,1),
        //         "", 1.0, true, 0.25, true ).
        //     util_hud_push_left("ap_orb_nav_do_w", "w:" + round_vec(w_v,1) + char(10) + 
        //                                         "astr: " + round_vec(a_applied,1) + char(10)).
        //     set head_dir to ship:facing.
        //     set AERO_Q to true.
        // } else {
        //     set orb_debug_vec1 to VECDRAW(V(0,0,0), V(0,0,1), RGB(0,0,1),
        //         "", 1.0, false, 0.25, true ).
        // }

        local head_error is (-ship:facing)*head_dir.
        set total_head_align to 0.5*head_error:forevector*V(0,0,1) + 0.5*head_error:starvector*V(1,0,0).
        set ALIGNED to total_head_align >= RCS_MIN_ALIGN.
        // set orb_steer_direction to head_dir.

        local w_error_py is convex(
            V(K_PITCH*wrap_angle(head_error:pitch), K_YAW*wrap_angle(head_error:yaw),0),
            w_v,
            aero_convex). // ignore roll first

        if w_error_py:mag > 2.5 {
            set w_error_py:z to 0.
        } else {
            set w_error_py:z to K_ROLL*wrap_angle(head_error:roll).
        }

        ap_orb_w(-w_error_py:x, w_error_py:y, - w_error_py:z, true).


        // set STEER_RCS to USE_RCS_STEER and (not ALIGNED or DO_BURN).
        // set MOVE_RCS to not DO_BURN and delta_v:mag > 0.0005 and ALIGNED.
        
        set RCS to (MOVE_RCS or STEER_RCS).

        if MOVE_RCS {
            local saturated_delta_v is delta_v:normalized*min(delta_v:mag,RCS_MAX_DV).
            set ship:control:translation to V(
                pwm_alivezone(K_RCS_STARBOARD*(ship:facing:starvector*saturated_delta_v) ),
                pwm_alivezone(K_RCS_TOP*(ship:facing:topvector*saturated_delta_v) ),
                pwm_alivezone(K_RCS_FORE*(ship:facing:forevector*saturated_delta_v) )).
        } else {
            set ship:control:translation to V(0,0,0).
        }

        set last_stage to stage:number.

        if (false) {
            util_hud_push_left( "ap_orb_nav_do",
                "medv "  + round_vec((-ship:facing)*delta_v,3) + char(10) +
                "ma align" + round(me_align,3) + char(10) +
                "dv "  + round_dec(delta_v:mag,3) +
                + "(" + round_dec(ship:facing:starvector*delta_v,2) + "," +
                    round_dec(ship:facing:topvector*delta_v,2) + "," +
                    round_dec(ship:facing:forevector*delta_v,2) +")" + char(10) ).
        }
    }
}

function ap_orb_status_string {
    return "G "+ round_dec( get_max_applied_acc()/g0, 1) +
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

        local prate_max is 90.
        local yrate_max is 90.
        local rrate_max is 360.

        if direct_mode {
            set pratePID:SETPOINT to -sat(u1,prate_max)*DEG2RAD.
            set yratePID:SETPOINT to sat(u2,yrate_max)*DEG2RAD.
            set rratePID:SETPOINT to -sat(u3,rrate_max)*DEG2RAD.
        } else {
            local omega_v is ap_stick_w(u1,u2,u3).
            set pratePID:SETPOINT to -omega_v:x*prate_max*DEG2RAD.
            set yratePID:SETPOINT to omega_v:y*yrate_max*DEG2RAD.
            set rratePID:SETPOINT to -omega_v:z*rrate_max*DEG2RAD.
        }

        // local pitch_rate is -((SHIP:ANGULARVEL)*SHIP:FACING:STARVECTOR).
        // local yaw_rate is ((SHIP:ANGULARVEL)*SHIP:FACING:TOPVECTOR).
        // local roll_rate is -((SHIP:ANGULARVEL)*SHIP:FACING:FOREVECTOR).

        local omega is (-ship:facing)*ship:angularvel.

        local MOI is get_moment_of_inertia().
        local B is control_bu().
        local A is control_aalpha() + 0*vcrs( omega, V(MOI:x*omega:x,MOI:y*omega:y,MOI:z*omega:z) ).

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
                char(10) + "pask" + " " + round_dec(RAD2DEG*pratePID:SETPOINT,1) + "/" + round_dec(prate_max,1) +
                char(10) + "pact" + " " + round_dec(RAD2DEG*omega:x,1) +
                char(10) + "perr" + " " + round_dec(RAD2DEG*pratePID:ERROR,1) ).
        }
        if (true) { // yaw debug
            util_hud_push_left( "ap_orb_wy",
                char(10) + "ypid" + " " + round_dec(yratePID:KP,2) + " " + round_dec(yratePID:KI,2) + " " + round_dec(yratePID:KD,2) +
                char(10) + "yask" + " " + round_dec(RAD2DEG*yratePID:SETPOINT,1) + "/" + round_dec(yrate_max,1) +
                char(10) + "yact" + " " + round_dec(RAD2DEG*omega:y,1) +
                char(10) + "yerr" + " " + round_dec(RAD2DEG*yratePID:ERROR,1) ).
        }
        if (true) { // pitch debug
            util_hud_push_left( "ap_orb_wz",
                char(10) + "rpid" + " " + round_dec(rratePID:KP,2) + " " + round_dec(rratePID:KI,2) + " " + round_dec(rratePID:KD,2) +
                char(10) + "rask" + " " + round_dec(RAD2DEG*rratePID:SETPOINT,1) + "/" + round_dec(rrate_max,1) +
                char(10) + "ract" + " " + round_dec(RAD2DEG*omega:z,1) +
                char(10) + "rerr" + " " + round_dec(RAD2DEG*rratePID:ERROR,1) +
                char(10) + "rout" + " " + round_dec(rratePID:output,1) ).
        }
    }
}
