
global AP_NAV_TAR_ENABLED is true.

local PARAM is readJson("1:/param.json")["AP_NAV"].
local INTERCEPT_DISTANCE is get_param(PARAM, "TARGET_INTERCEPT_DISTANCE_MAX", 1000).
local DOCK_DISTANCE is get_param(PARAM, "TARGET_DOCK_DISTANCE_MAX", 200).
local DOCK_SPEED is get_param(PARAM, "TARGET_DOCK_SPEED_MAX", 10).
local VSET_MAX is get_param(PARAM, "VSET_MAX", 280).


function ap_nav_tar_wp_guide {
    parameter wp.

    local offsvec is get_param(wp, "offsvec", V(0,0,0)).
    local radius is get_param(wp, "radius", 1.0).
    local approach_speed is get_param(wp, "speed", 3.0).

    local current_nav_velocity is ap_nav_get_vessel_vel().

    if HASTARGET {
        local target_ship is target.
        local target_nav_velocity is ap_nav_get_vessel_vel(target_ship).
        local relative_velocity is current_nav_velocity-target_nav_velocity.
        local final_head is target:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(180,0,0)).
        local position is target_ship:position + (final_head)*offsvec.

        local align_data is list().

        if (position:mag < DOCK_DISTANCE) and (approach_speed < DOCK_SPEED) {
            // close enough and set to dock
            set align_data to ap_nav_align(position, final_head, relative_velocity, radius).
            return list(approach_speed*align_data[0]+target_nav_velocity ,V(0,0,0), final_head).
        } else { // do a surface (q) or orbital intercept
            if true {
                set approach_speed to target_nav_velocity:mag+VSET_MAX*sat(position:mag/INTERCEPT_DISTANCE).
                local t_bear is pitch_yaw_from_dir(position:direction)[1].
                set align_data to ap_nav_q_target(target:altitude, target_nav_velocity:mag, t_bear).
                return list(approach_speed*align_data[0]+target_nav_velocity ,V(0,0,0), final_head).

            } else {
                // figure out how to choose later
            }
        }


    } else if false {
        // get stored target from shsys
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