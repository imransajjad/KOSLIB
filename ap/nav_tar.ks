
global AP_NAV_TAR_ENABLED is true.

function ap_nav_tar_wp_guide {
    parameter wp.

    local offsvec is get_param(wp, "offsvec", V(0,0,0)).
    local radius is get_param(wp, "radius", 1.0).
    local approach_speed is get_param(wp, "velocity", 1.0).

    if HASTARGET {
        local position is target:position.
        local target_velocity is (choose target:velocity if target_ship:hassuffix("velocity") else target:ship:velocity).
        local final_head is target:facing*(choose 1 if target_ship:hassuffix("velocity") else R(180,0,0)).

        local align_data is ap_nav_align(position, final_head, ship:velocity:orbit-target_velocity:orbit, radius).

        return list(approach_speed*align_data[0]+current_nav_velocity ,V(0,0,0), final_head).
    } else {
        // do nothing
        return list(V(0,0,0),V(0,0,0),ship:facing).
    }
}

function ap_nav_tar_stick {
    
}

function ap_nav_tar_do {

}

function ap_nav_tar_status_string {
    return "".
}