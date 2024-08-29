
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

local pred_weights is list(28,-63,36). // weights to predict future position
local last_three_distances is list(28,-63,36). // initialize to max
local function ap_nav_tar_check_done {
    parameter position. // position vector to target
    parameter threshold. // 

    last_three_distances:remove(0).
    last_three_distances:add(position:mag).

    local future_position is pred_weights[0]*last_three_distances[0] +
                        pred_weights[1]*last_three_distances[1] +
                        pred_weights[2]*last_three_distances[2].
    return ( abs(future_position) < threshold).
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
        if approach_speed > MAX_STATION_KEEP_SPEED and ap_nav_tar_check_done(position, radius/5) {
            ap_nav_wp_done().
        }
        set approach_speed to sat(position:mag/radius, 1)*abs(approach_speed).

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