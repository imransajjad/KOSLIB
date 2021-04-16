
global AP_HOVER_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_HOVER", lexicon()).

local STICK_GAIN_NOM is get_param(PARAM, "STICK_GAIN", 3.0).
local lock STICK_GAIN to STICK_GAIN_NOM*(choose 0.25 if AG else 1.0).

// USES AG6
local lock AG to AG6.
local lock CONTROL_DIR to (choose 1 if AG5 else -1).

local K_VEL is get_param(PARAM, "K_VEL", 6.25).
local hover_pid is pidLoop(
    get_param(PARAM, "VS_KP", 1.0)*K_VEL,
    get_param(PARAM, "VS_KI", 0.1)*K_VEL,
    get_param(PARAM, "VS_KD", 0.75)*K_VEL,
    -3*g0,3*g0).

local ATT_INERTIA is get_param(PARAM, "ATT_INERTIA", 0.5).
local P_KP is get_param(PARAM, "P_KP", 1.0).
local P_KI is get_param(PARAM, "P_KI", 1.5).
local P_KD is get_param(PARAM, "P_KD", 0.35).
local pitch_pid is pidLoop(P_KP, P_KI, P_KD, -1.0,1.0).

local Y_KP is get_param(PARAM, "Y_KP", P_KP).
local Y_KI is get_param(PARAM, "Y_KI", P_KI).
local Y_KD is get_param(PARAM, "Y_KD", P_KD).
local yaw_pid is pidLoop(Y_KP, Y_KI, Y_KD, -1.0,1.0).

local I2G is ATT_INERTIA*ship:mass.

local RR_K is get_param(PARAM, "RR_K", 0.05).

local max_vertical_speed is get_param(PARAM, "VS_MAX", 15).
local max_tilt is get_param(PARAM, "TILT_MAX", 15).
local max_roll_rate is get_param(PARAM, "ROLLRATE_MAX", 30).

local K_ROLL is get_param(PARAM, "K_ROLL", 1.5).

local Elist is get_engines(get_param(PARAM, "MAIN_ENGINE_NAME", "")).

local upvec is ship:up:vector.
local my_throttle is 0.0.

lock throttle to my_throttle.
// unlock throttle.
local lock max_tmr to get_total_tmr().

local last_tmr is 0.1.
local last_tmr_time is 0.
local function get_total_tmr {
    if time:seconds > last_tmr_time + 0.01 {
        local thrust is 0.
        for e in Elist {
            set thrust to thrust+e:maxthrust.
        }
        set last_tmr to thrust/ship:mass.
    }
    return last_tmr.
}

local function gain_update {
    // gain update
    if ship:control:pilottop > 0.5 {
        set ATT_INERTIA to ATT_INERTIA + 0.01.
    } else if ship:control:pilottop < -0.5 {
        set ATT_INERTIA to max(0.01,ATT_INERTIA - 0.01).
    }
    set I2G to ATT_INERTIA*ship:mass/kuniverse:timewarp:rate*DEG2RAD.

    set pitch_pid:KP to P_KP*I2G.
    set pitch_pid:KI to P_KI*I2G.
    set pitch_pid:KD to P_KD*I2G.

    set yaw_pid:KP to Y_KP*I2G.
    set yaw_pid:KI to Y_KI*I2G.
    set yaw_pid:KD to Y_KD*I2G.
}

local function hover_do_control {
    parameter acc_up.
    parameter pitch_target.
    parameter yaw_target.
    parameter roll_rate_target.

    gain_update().
    display_land_stats().

    set pitch_target to sat(pitch_target,max_tilt).
    set yaw_target to sat(yaw_target,max_tilt).
    set roll_rate_target to sat(roll_rate_target,max_roll_rate).

    if ship:status = "LANDED" or ship:status = "SPLASHED" {
        set pitch_target to 0.
        set yaw_target to 0.
    }

    if max_tmr > 0 {
        local cos_up is ship:up:vector*ship:facing:vector.
        set my_throttle to max(0.001, acc_up/max_tmr/cos_up).
    } else {
        set my_throttle to 0.
    }
    // set ship:control:mainthrottle to my_throttle.

    local delta_dir is (-ship:facing)*ship:up.
    local pitch_tilt is wrap_angle(delta_dir:pitch).
    local yaw_tilt is wrap_angle(-delta_dir:yaw).
    local roll_rate is -RAD2DEG*ship:facing:vector*ship:angularvel.

    // attitude control
    if not SAS {
        set pitch_pid:setpoint to pitch_target.
        set yaw_pid:setpoint to yaw_target.

        pitch_pid:update(time:seconds, pitch_tilt).
        yaw_pid:update(time:seconds, yaw_tilt).

        set ship:control:pitch to pitch_pid:output.
        set ship:control:yaw to yaw_pid:output.
        set ship:control:roll to I2G*RR_K*(roll_rate_target - roll_rate).
    } else {
        set ship:control:neutralize to true.
    }
    if false {
        util_hud_push_left("hover_att", "p,y: " + round_dec(pitch_tilt,1) + "," + round_dec(yaw_tilt,1) +
        char(10) + "I2G " + round_dec(I2G,3) ).
    }

    if false {
        util_hud_push_left("hover_pitch",
        "pt/" + char(916) + ": " + round_dec(pitch_pid:setpoint,1) + "," + round_dec(pitch_pid:error,1) +
        char(10) + "pPID " + round_dec(pitch_pid:KP,1) + "," + round_dec(pitch_pid:KI,1) + "," + round_dec(pitch_pid:KD,1) +
        char(10) + "yt/" + char(916) + ": " + round_dec(yaw_pid:setpoint,1) + "," + round_dec(yaw_pid:error,1) +
        char(10) + "yPID " + round_dec(yaw_pid:KP,1) + "," + round_dec(yaw_pid:KI,1) + "," + round_dec(yaw_pid:KD,1)).
    }
}

function ap_hover_do {
    parameter u0 is ship:control:pilotmainthrottle.
    parameter u1 is ship:control:pilotpitch.
    parameter u2 is ship:control:pilotyaw.
    parameter u3 is ship:control:pilotroll.
    
    local vs_target is round_dec(max_vertical_speed*(2*u0 - 1), 1).
    local vs_error is vs_target-ship:velocity:surface*ship:up:vector.

    if false {
        util_hud_push_left("hover_vvel",
        "vt/" + char(916) + ": " + round_dec(vs_target,1) + "," + round_dec(vs_error,1) +
        char(10) + "T " + round_dec(max_tmr,1) +
        char(10) + "o/i " + round_dec(my_throttle,1)).
    }

    set hover_pid:setpoint to vs_target.
    hover_pid:update(time:seconds, ship:velocity:surface*ship:up:vector).

    hover_do_control( hover_pid:output - GRAV_ACC*ship:up:vector,
            CONTROL_DIR*STICK_GAIN*u1*max_tilt,
            -CONTROL_DIR*STICK_GAIN*u2*max_tilt,
            CONTROL_DIR*STICK_GAIN*u3*max_roll_rate).
}


function ap_hover_nav_do {
    parameter vel_vec is AP_NAV_VEL.
    parameter acc_vec is AP_NAV_ACC.
    parameter head_dir is AP_NAV_ATT.

    local acc_applied is K_VEL*(vel_vec - ship:velocity:surface) + acc_vec - GRAV_ACC.
    if not AP_NAV_IN_SURFACE {
        set acc_applied to K_VEL*(vel_vec - ship:velocity:orbit) + acc_vec.
    }

    set hover_pid:setpoint to vel_vec*upvec.
    hover_pid:update(time:seconds, ship:velocity:surface*upvec).

    local base_frame is lookDirUp(ship:up:vector, ship:facing:topvector).
    local delta_dir is (-ship:facing)*AP_NAV_ATT.
    local roll_error is convex(
        wrap_angle(delta_dir:roll),
        0,
        vectorexclude(ship:up:vector,acc_applied):mag ).
        // 0 ).

    local current_mtr is 0.
    if max_tmr > 0 {
        set current_mtr to 1/max_tmr.
    }

    hover_do_control( (hover_pid:output - GRAV_ACC*ship:up:vector + acc_vec*upvec),
            acc_applied*base_frame:topvector*current_mtr/DEG2RAD,
            acc_applied*base_frame:starvector*current_mtr/DEG2RAD,
            K_ROLL*roll_error).
}

function ap_hover_status_string {
    return "vst " + round_dec(hover_pid:setpoint,1) +
        char(10) + char(916) + " " + round_dec(hover_pid:error,1).
}
