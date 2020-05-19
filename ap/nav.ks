
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

local lock cur_vel_head to heading(vel_bear, vel_pitch).

local USE_UTIL_WP is readJson("1:/param.json"):haskey("UTIL_WP").

local lock W_PITCH_NOM to max(50,vel)/(g0*ROT_GNOM_VERT).
local lock W_YAW_NOM to max(50,vel)/(g0*ROT_GNOM_LAT).

global AP_NAV_V_SET_PREV is -1.0.
global AP_NAV_V_SET is vel.
global AP_NAV_E_SET is vel_pitch.
global AP_NAV_H_SET is vel_bear.
global AP_NAV_R_SET is roll.

global AP_NAV_W_E_SET is 0.0.
global AP_NAV_W_H_SET is 0.0.
global AP_NAV_W_R_SET is 0.0.

global AP_NAV_TIME_TO_WP is 0.

local lock in_orbit to (ship:apoapsis > 20000).
local lock in_surface to (ship:altitude < 36000).
local lock in_target to (HASTARGET).

function ap_nav_display {
    // for waypoint in waypoint_queue, set pitch, heading to waypoint, else
    // manually control heading.

    // in flcs mode"
    //      if wp exists, set nav to wp, set dnav to no set
    //      else do nothing
    // if vel mode
    //      if wp exists, set nav to wp, set dvel to manual, set dpitch dbear to no set.
    //      else,           set nav to current heading, set dvel to manual.
    // if nav mode
    //      if wp exists, set nav to wp, set dnav to no set
    //      else,           set dnav to manual


    set AP_NAV_V_SET_PREV to AP_NAV_V_SET.

    if USE_UTIL_WP and (util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        if cur_wayp["mode"] = "srf" {
            ap_nav_srf_wp_guide(cur_wayp).
        } else if cur_wayp["mode"] = "orb" {
            ap_nav_orb_wp_guide(cur_wayp).
        } else if cur_wayp["mode"] = "tar" {
            ap_nav_tar_wp_guide(cur_wayp).
        }
    } else {
        if in_surface {
            ap_nav_srf_stick().
        }
        if in_orbit {
            // ap_nav_orb_stick().
        }
        if in_target {
            ap_nav_tar_stick().
        }
    }
    // all of the above functions can contribute to setting
    // NAV_V, NAV_PRO, NAV_FACE, NAV_A, NAV_W_PRO, NAV_W_FACE
}

function ap_nav_get_data {
    return list(AP_NAV_V_SET,AP_NAV_H_SET,AP_NAV_E_SET,AP_NAV_R_SET).
}

function ap_nav_get_direction {
    return heading(AP_NAV_H_SET,AP_NAV_E_SET,AP_NAV_R_SET).
}

function ap_nav_get_vel {
    return AP_NAV_V_SET.
}

function ap_nav_get_time_to_wp {
    if true {
        return round(min(9999,AP_NAV_TIME_TO_WP)).
    } else {
        return 0.
    }
}

function ap_nav_do {
    // NAV_V, NAV_PRO, NAV_FACE, NAV_A, NAV_W_PRO, NAV_W_FACE
    // are used by these functions
    if in_surface {
        ap_nav_do_aero_rot().
    } 
    if in_orbit {
        // ap_nav_do_orb_nav().
    }
    if in_target {
        // ap_nav_do_tar().
    }
}

function ap_nav_status_string {
    local dstr is "".
    if in_surface {
        set dstr to dstr+ap_nav_srf_status_string().
    }
    if in_orbit {
        set dstr to dstr+ap_nav_orb_status_string().
    }
    if in_target {
        set dstr to dstr+ap_nav_tar_status_string().
    }

    return dstr.
}
