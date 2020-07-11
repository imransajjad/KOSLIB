
global AP_NAV_TAR_ENABLED is true.

local PARAM is readJson("1:/param.json")["AP_NAV"].
local INTERCEPT_DISTANCE is get_param(PARAM, "MAX_TARGET_INTERCEPT_DISTANCE", 1200).
local MAX_STATION_KEEP_SPEED is get_param(PARAM, "MAX_STATION_KEEP_SPEED", 1.0).


function ap_nav_tar_wp_guide {
    parameter wp.

    local offsvec is get_param(wp, "offsvec", V(0,0,0)).
    local radius is get_param(wp, "radius", 1.0).
    local approach_speed is get_param(wp, "speed", 3.0).

    local current_nav_velocity is ap_nav_get_vessel_vel().

    local target_ship is util_shsys_get_target().

    if not (target_ship = -1) {
        local target_nav_velocity is ap_nav_get_vessel_vel(target_ship).
        local relative_velocity is current_nav_velocity-target_nav_velocity.
        local final_head is target:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(180,0,0)).
        local position is target_ship:position + (final_head)*offsvec.

        if position:mag > INTERCEPT_DISTANCE {
            // do nothing
            return list(current_nav_velocity,V(0,0,0),ship:facing).
        }

        if approach_speed > MAX_STATION_KEEP_SPEED {
            ap_nav_check_done(position, ship:facing, relative_velocity, radius).
        } else if approach_speed >= 0 {
            set approach_speed to sat(position:mag/radius, 2*MAX_STATION_KEEP_SPEED).
        } else {
            set approach_speed to -approach_speed + sat(position:mag/radius, -2*approach_speed).
        }
        
        if defined UTIL_HUD_ENABLED {
            util_hud_push_right("nav_tar", "a_s " + round_dec(approach_speed,1) + char(10)+
                round_dec(position*final_head:starvector,2) + char(10)+ round_dec(position*final_head:topvector,2) + char(10)+ round_dec(position*final_head:forevector,2)).
        }

        local align_data is ap_nav_align(position, final_head, relative_velocity, radius).
        return list(approach_speed*align_data[0]+target_nav_velocity, align_data[1], final_head).
        // return list(approach_speed*position:normalized+target_nav_velocity ,V(0,0,0), final_head).
    } else {
        // do nothing
    }
    return list(current_nav_velocity,V(0,0,0),ship:facing).
}

function ap_nav_tar_stick {
    
}

function ap_nav_tar_do {

}

function ap_nav_tar_status_string {
    return "".
}