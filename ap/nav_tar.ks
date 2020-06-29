
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

    local target_ship is -1.
    if HASTARGET {
        set target_ship to target.
    } else if false and util_shsys_has_target() {
        set target_ship to util_shsys_get_target().
    }

    if not (target_ship = -1) {
        local target_nav_velocity is ap_nav_get_vessel_vel(target_ship).
        local relative_velocity is current_nav_velocity-target_nav_velocity.
        local final_head is target:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(180,0,0)).
        local position is target_ship:position + (final_head)*offsvec.

        // local align_data is ap_nav_align(position, final_head, relative_velocity, radius).
        // return list(approach_speed*align_data[0]+target_nav_velocity ,V(0,0,0), final_head).
        return list(approach_speed*position:normalized+target_nav_velocity ,V(0,0,0), final_head).
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