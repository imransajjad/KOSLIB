
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

local DOCK_DISTANCE is get_param(PARAM, "TARGET_DOCK_DISTANCE_MAX", 200).

local lock cur_vel_head to heading(vel_bear, vel_pitch).

global AP_NAV_V_SET_PREV is -1.0.
global AP_NAV_V_SET is vel.
global AP_NAV_E_SET is vel_pitch.
global AP_NAV_H_SET is vel_bear.
global AP_NAV_R_SET is 0.

global AP_NAV_W_E_SET is 0.0.
global AP_NAV_W_H_SET is 0.0.
global AP_NAV_W_R_SET is 0.0.

global AP_NAV_TIME_TO_WP is 0.

local USE_GCAS is get_param(PARAM,"GCAS_ENABLED",false).
local USE_UTIL_WP is false.
local SRF_ENABLED is false.
local ORB_ENABLED is false.
local TAR_ENABLED is false.

local lock in_orbit to (ship:apoapsis > 20000).
local lock in_surface to (ship:altitude < 36000).
local lock in_docking to (HASTARGET and target:distance < DOCK_DISTANCE).


local flags_updated is false.
local function update_flags {
    if not flags_updated {
        set SRF_ENABLED to defined AP_NAV_SRF_ENABLED.
        set ORB_ENABLED to defined AP_NAV_ORB_ENABLED.
        set TAR_ENABLED to defined AP_NAV_TAR_ENABLED.
        set USE_UTIL_WP to defined UTIL_WP_ENABLED.
        set flags_updated to true.
    }
}

function ap_nav_display {

    update_flags().

    if in_surface and USE_GCAS and ap_nav_srf_gcas(){
        return.
    }


    set AP_NAV_V_SET_PREV to AP_NAV_V_SET.

    if USE_UTIL_WP and (util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        if SRF_ENABLED and cur_wayp["mode"] = "srf" {
            ap_nav_srf_wp_guide(cur_wayp).
        } else if ORB_ENABLED and cur_wayp["mode"] = "orb" {
            ap_nav_orb_wp_guide(cur_wayp).
        } else if TAR_ENABLED and cur_wayp["mode"] = "tar" {
            ap_nav_tar_wp_guide(cur_wayp).
        } else {
            print "got unsupported wp, marking it done".
            util_wp_done().
        }
    } else {
        if SRF_ENABLED and in_surface {
            ap_nav_srf_stick().
        }
        if ORB_ENABLED and in_orbit {
            // ap_nav_orb_stick().
        }
        if TAR_ENABLED and in_docking {
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
    return round(min(9999,AP_NAV_TIME_TO_WP)).
}

function ap_nav_do {
    // NAV_V, NAV_PRO, NAV_FACE, NAV_A, NAV_W_PRO, NAV_W_FACE
    // are used by these functions
    if SRF_ENABLED and in_surface {
        unlock steering.
        ap_nav_do_aero_rot().
    } else if ORB_ENABLED and in_orbit {
        ap_nav_orb_do().
    } else if SRF_ENABLED {
        unlock steering.
        ap_nav_do_aero_rot().
    } else if ORB_ENABLED {
        ap_nav_orb_do().
    } else if false {
        ap_nav_tar_do().
    }
}

function ap_nav_status_string {
    local dstr is "".
    if SRF_ENABLED and in_surface {
        set dstr to dstr+ap_nav_srf_status_string().
    }
    if ORB_ENABLED and in_orbit {
        set dstr to dstr+ap_nav_orb_status_string().
    }
    if TAR_ENABLED and in_docking {
        set dstr to dstr+ap_nav_tar_status_string().
    }

    return dstr.
}
