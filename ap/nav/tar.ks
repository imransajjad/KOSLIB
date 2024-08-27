
GLOBAL AP_NAV_TAR_ENABLED IS TRUE.
local PARAM is get_param(readJson("param.json"), "AP_NAV_TAR", lexicon()).

local INTERCEPT_DISTANCE is get_param(PARAM, "MAX_TARGET_INTERCEPT_DISTANCE", 1200).
local MAX_STATION_KEEP_SPEED is get_param(PARAM, "MAX_STATION_KEEP_SPEED", 10).

local approach_speed is 0.
local position is V(0,0,0).
local final_head is R(0,0,0).

local relative_velocity is V(0,0,0).
local slow_roll is 0.
local relative_roll is 0.

local function ap_nav_tar_check_done {
    parameter final_speed. // final speed upon approach
    parameter vec_final. // position vector to target
    parameter head_final. // desired heading upon approach
    parameter frame_vel. // a velocity vector in this frame
    parameter radius. // a turning radius.

    local time_dir is frame_vel*vec_final:normalized.
    local time_to is vec_final:mag/max(frame_vel:mag,0.0001).

    if (time_to < 3) and (final_speed > MAX_STATION_KEEP_SPEED) {
        local angle_to is vectorangle(vec_final,frame_vel).

        if ( angle_to > 30) or
            (angle_to > 12.5 and time_to < 2) or 
            ( time_to < 1) {
            return true.
        }
    }
    return false.
}

function ap_nav_tar_wp_guide {
    parameter wp.

    local wp_done is false.
    local new_roll is relative_roll.
    if wp:haskey("roll") {
        set new_roll to wp["roll"].
    } else if defined AP_MODE_ENABLED and AP_MODE_NAV {
        local delta_slow is sign(deadzone(ship:control:pilotroll,0.5)).
        set slow_roll to slow_roll+0.25*delta_slow.
        set new_roll to 15*round_dec(slow_roll,0).
    }
    if new_roll <> relative_roll {
        set relative_roll to new_roll.
        print "tar roll " + relative_roll.
    }

    local radius is max(get_param(wp, "radius", 1.0), 0.05).
    set approach_speed to get_param(wp, "speed", 3.0).
    local offsvec is get_param(wp, "offsvec", V(0,0,-abs(radius)) ).

    local target_ship is -1.
    if defined UTIL_SHSYS_ENABLED {
        set target_ship to util_shsys_get_target().
    } else if HASTARGET {
        set target_ship to TARGET.
    }

    if not (target_ship = -1) {
        set relative_velocity to ap_nav_get_vessel_vel()-ap_nav_get_vessel_vel(target_ship).
        set final_head to target_ship:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(0,180,0)).
        local position is -ship:controlpart:position + target_ship:position + (final_head)*offsvec.
        if position:mag > INTERCEPT_DISTANCE {
            return false. // do nothing
        }
        if ap_nav_tar_check_done(approach_speed, position, ship:facing, relative_velocity, radius) {
            ap_nav_wp_done().
        }
        if approach_speed <= MAX_STATION_KEEP_SPEED {
            set approach_speed to sat(position:mag/radius, 1)*abs(approach_speed).
        }

        set AP_NAV_VEL to approach_speed*position:normalized+ap_nav_get_vessel_vel(target_ship).
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to final_head*R(0,0,-relative_roll).

        return true.
    } else {
        return false.
    }
}

function ap_nav_tar_status_string {
    local dstr is "".
    local mode_str is "".
    local vel_mag is ap_nav_get_hud_vel():mag.
    set dstr to dstr + "/"+round_fig(vel_mag,2).
    set mode_str to mode_str + "t".

    return dstr.
}