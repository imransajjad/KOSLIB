
global AP_HOVER_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_HOVER", lexicon()).

local pitch_pid is pidLoop(
    get_param(PARAM, "P_KP", 1.0),
    get_param(PARAM, "P_KI", 1.8),
    get_param(PARAM, "P_KD", 0.2),
    -1.0,1.0).

local yaw_pid is pidLoop(
    get_param(PARAM, "Y_KP", get_param(PARAM, "P_KP", 1.0)),
    get_param(PARAM, "Y_KI", get_param(PARAM, "P_KI", 1.8)),
    get_param(PARAM, "Y_KD", get_param(PARAM, "P_KD", 0.2)),
    -1.0,1.0).
local ATT_INERTIA is get_param(PARAM, "ATT_INERTIA", 0.1).

local RR_K is get_param(PARAM, "RR_K", 0.05).

local CONTROL_DIR is -1.

local max_vertical_speed is get_param(PARAM, "VS_MAX", 15).
local max_tilt is get_param(PARAM, "TILT_MAX", 15).
local max_roll_rate is get_param(PARAM, "ROLLRATE_MAX", 30).

local K_VEL is get_param(PARAM, "K_VEL", 0.25).
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
        // local cos_up is cos(pitch_target)*cos(yaw_target).
        // set my_throttle to max(0.001, acc_up/max_tmr/cos_up).

        local exc_up is vectorExclude(upvec,(R(pitch_target,yaw_target,0)*upvec)).
        local a_applied is acc_up*upvec + max_tmr*exc_up.
        local cos_applied is ship:facing:vector*a_applied:normalized.
        set my_throttle to max(0.001, a_applied:mag/max_tmr/cos_applied).
    } else {
        set my_throttle to 0.
    }
    // set ship:control:mainthrottle to my_throttle.

    // attitude control
    local delta_dir is (-ship:facing)*ship:up.
    local pitch_tilt is wrap_angle(delta_dir:pitch).
    local yaw_tilt is wrap_angle(-delta_dir:yaw).
    
    local roll_rate is -RAD2DEG*ship:facing:vector*ship:angularvel.
    local target_roll_rate is roll_rate.

    if not SAS {
        set pitch_pid:setpoint to pitch_target*ATT_INERTIA.
        set yaw_pid:setpoint to yaw_target*ATT_INERTIA.

        pitch_pid:update(time:seconds, pitch_tilt*ATT_INERTIA).
        yaw_pid:update(time:seconds, yaw_tilt*ATT_INERTIA).

        set ship:control:pitch to pitch_pid:output.
        set ship:control:yaw to yaw_pid:output.
        set ship:control:roll to RR_K*DEG2RAD*(roll_rate_target - roll_rate).
    } else {
        set ship:control:neutralize to true.
    }
    if true {
        util_hud_push_left("hover_att", "p,y: " + round_dec(pitch_tilt,1) + "," + round_dec(yaw_tilt,1)).
    }

    if true {
        util_hud_push_left("hover_pitch",
        "pt/" + char(916) + ": " + round_dec(pitch_pid:setpoint/ATT_INERTIA,1) + "," + round_dec(pitch_pid:error/ATT_INERTIA,1) +
        char(10) + "pPID " + round_dec(pitch_pid:KP,1) + "," + round_dec(pitch_pid:KI,1) + "," + round_dec(pitch_pid:KD,1) +
        char(10) + "o/i " + round_dec(pitch_pid:output,1) + "," + round_dec(ATT_INERTIA,2)).
    }
    if true {
        util_hud_push_left("hover_yaw",
        "yt/" + char(916) + ": " + round_dec(yaw_pid:setpoint/ATT_INERTIA,1) + "," + round_dec(yaw_pid:error/ATT_INERTIA,1) +
        char(10) + "yPID " + round_dec(yaw_pid:KP,1) + "," + round_dec(yaw_pid:KI,1) + "," + round_dec(yaw_pid:KD,1) +
        char(10) + "o/i " + round_dec(yaw_pid:output,1) + "," + round_dec(ATT_INERTIA,2)).
    }
}

function ap_hover_do {
    parameter u0 is ship:control:pilotmainthrottle.
    parameter u1 is ship:control:pilotpitch.
    parameter u2 is ship:control:pilotyaw.
    parameter u3 is ship:control:pilotroll.
    
    local vs_target is round_dec(max_vertical_speed*(2*u0 - 1), 1).
    local vs_error is vs_target-ship:velocity:surface*ship:up:vector.

    if true {
        util_hud_push_left("hover_vvel",
        "vt/" + char(916) + ": " + round_dec(vs_target,1) + "," + round_dec(vs_error,1) +
        char(10) + "T " + round_dec(max_tmr,1) +
        char(10) + "o/i " + round_dec(my_throttle,1)).
    }

    hover_do_control( K_VEL*vs_error - GRAV_ACC*ship:up:vector,
            CONTROL_DIR*u1*max_tilt,
            -CONTROL_DIR*u2*max_tilt,
            CONTROL_DIR*u3*max_roll_rate).
}


function ap_hover_nav_do {
    parameter vel_vec is AP_NAV_VEL.
    parameter acc_vec is AP_NAV_ACC.
    parameter head_dir is AP_NAV_ATT.

    local acc_applied is K_VEL*(vel_vec - ship:velocity:surface) + acc_vec - GRAV_ACC.
    if not AP_NAV_IN_SURFACE {
        set acc_applied to K_VEL*(vel_vec - ship:velocity:orbit) + acc_vec.
    }
    
    local base_frame is lookDirUp(ship:up:vector, ship:facing:topvector).
    local delta_dir is (-ship:facing)*AP_NAV_ATT.
    local roll_error is convex(
        wrap_angle(delta_dir:roll),
        0,
        vectorexclude(ship:up:vector,acc_applied):mag ).
        // 0 ).

    local current_tmr is 9999999999.
    if max_tmr > 0 {
        set current_tmr to max_tmr.
    }

    hover_do_control( acc_applied*base_frame:forevector,
            acc_applied*base_frame:topvector/current_tmr/DEG2RAD,
            acc_applied*base_frame:starvector/current_tmr/DEG2RAD,
            K_ROLL*roll_error).
}
