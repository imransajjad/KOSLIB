
global AP_NAV_TAR_ENABLED is true.

local PARAM is readJson("1:/param.json")["AP_NAV"].
local INTERCEPT_DISTANCE is get_param(PARAM, "MAX_TARGET_INTERCEPT_DISTANCE", 1200).
local MAX_STATION_KEEP_SPEED is get_param(PARAM, "MAX_STATION_KEEP_SPEED", 1.0).

local approach_speed is 0.
local position is V(0,0,0).
local final_head is R(0,0,0).

local relative_velocity is V(0,0,0).

local target_wp_on is false.

function ap_nav_tar_wp_guide {
    parameter wp.

    local radius is get_param(wp, "radius", 1.0).
    set approach_speed to get_param(wp, "speed", 3.0).
    local offsvec is get_param(wp, "offsvec", V(0,0,-abs(radius)) ).

    local current_nav_velocity is ap_nav_get_vessel_vel().

    local target_ship is util_shsys_get_target().

    if not (target_ship = -1) {
        local target_nav_velocity is ap_nav_get_vessel_vel(target_ship).
        set relative_velocity to current_nav_velocity-target_nav_velocity.
        set final_head to target:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(0,180,0)).
        set position to target_ship:position + (final_head)*offsvec.

        if position:mag > INTERCEPT_DISTANCE {
            // do nothing
            set target_wp_on to false.
            set AP_NAV_VEL to current_nav_velocity.
            set AP_NAV_ACC to V(0,0,0).
            set AP_NAV_ATT to ship:facing.
            return.
        }
        set target_wp_on to true.

        if approach_speed > MAX_STATION_KEEP_SPEED {
            ap_nav_check_done(position, ship:facing, relative_velocity, radius).
        } else {
            set approach_speed to sat(position:mag/radius, 1)*abs(approach_speed).
        }

        local align_data is ap_nav_align(position, final_head, relative_velocity, radius).

        set AP_NAV_VEL to approach_speed*align_data[0]+ap_nav_get_vessel_vel(target_ship).
        set AP_NAV_ACC to align_data[1].
        set AP_NAV_ATT to final_head.
    } else {
        // do nothing
        set target_wp_on to false.
        set AP_NAV_VEL to ship:velocity:orbit.
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
    }
}

function ap_nav_tar_status_string {
    local hud_str is "".
    if target_wp_on {
        set hud_str to hud_str + char(10) + "a>" + round_fig(approach_speed,1) + char(10)+
                "("+round_fig(position*final_head:starvector,2) + "," +
                round_fig(position*final_head:topvector,2) + "," +
                round_fig(position*final_head:forevector,2) + ")".
    }
    set target_wp_on to false.
    return hud_str.
}