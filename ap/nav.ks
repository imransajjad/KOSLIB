
GLOBAL AP_NAV_ENABLED IS TRUE.
// local PARAM is get_param(readJson("param.json"), "AP_NAV", lexicon()).

// NAV GLOBALS (other files should read but not write to these)
global AP_NAV_TIME_TO_WP is 0.

global AP_NAV_VEL is V(0,0,0). // is surface if < 36000, else orbital
global AP_NAV_ACC is V(0,0,0).
global AP_NAV_ATT is R(0,0,0).

global AP_NAV_IN_SURFACE is false. // use this global !!!
global AP_NAV_IN_ORBIT is true.

local previous_body is "Kerbin".
local body_navchange_alt is get_param(BODY_navball_change_alt, ship:body:name, 36000).

local DISPLAY_SRF is false.
local DISPLAY_ORB is false.
local DISPLAY_TAR is false.

local DISPLAY_HUD_VEL is false.
local CLEAR_HUD_VEL is false.

// returns the nav velocity of a vessel in "our" frame
function ap_nav_get_vessel_vel {
    parameter this_vessel is ship.
    if not this_vessel:hassuffix("velocity") {
        set this_vessel to this_vessel:ship.
    }
    if not this_vessel:loaded and
        (this_vessel:status = "LANDED" or this_vessel:status = "SPLASHED") {
            if AP_NAV_IN_SURFACE {
                return this_vessel:geoposition:altitudevelocity(this_vessel:altitude):surface.
            } else {
                return this_vessel:geoposition:altitudevelocity(this_vessel:altitude):orbit.
            }
        }
    else if AP_NAV_IN_SURFACE {
        return this_vessel:velocity:surface.
    } else {
        return this_vessel:velocity:orbit.
    }
}

// NAV TEST START

// directly set any nav data here for testing
local intercept_t is 10.
local ship_end_mass is 0.29600000.
local t_last is time:seconds.
local dv_r is 0.
local function navtest_wp {
    parameter wp.

    if not (wp["mode"] = "navtest") {
        return false.
    }

    return false.
}

// NAV TEST END

function ap_nav_display {

    if not (previous_body = ship:body:name) {
        set previous_body to ship:body:name.
        set body_navchange_alt to get_param(BODY_navball_change_alt, previous_body, 36000).
    }
    set AP_NAV_IN_ORBIT to (ship:apoapsis > body_navchange_alt) or (ship:apoapsis < 0).
    set AP_NAV_IN_SURFACE to (ship:altitude < body_navchange_alt).

    local cur_wayp is lexicon("mode","none").
    if defined UTIL_WP_ENABLED {
        set cur_wayp to util_wp_queue_first().
    }

    if cur_wayp["mode"] = "srf" and defined AP_NAV_SRF_ENABLED and ap_nav_srf_wp_guide(cur_wayp) {
        set DISPLAY_SRF to true.

    } else if cur_wayp["mode"] = "orb" and defined AP_NAV_ORB_ENABLED and ap_nav_orb_wp_guide(cur_wayp) {
        set DISPLAY_ORB to true.

    } else if cur_wayp["mode"] = "tar" and defined AP_NAV_TAR_ENABLED and ap_nav_tar_wp_guide(cur_wayp){
        set DISPLAY_TAR to true.

    } else if cur_wayp["mode"] = "navtest" and navtest_wp(cur_wayp) {
    //      set DISPLAY_ORB to AP_NAV_IN_ORBIT.
    // } else if navtest_wp(cur_wayp) {
         set DISPLAY_ORB to AP_NAV_IN_ORBIT.

    } else if AP_NAV_IN_ORBIT and defined AP_NAV_ORB_ENABLED and ap_nav_orb_mannode() {
        set DISPLAY_ORB to true.

    } else if AP_NAV_IN_SURFACE and defined AP_NAV_SRF_ENABLED and ap_nav_srf_stick() {
        set DISPLAY_SRF to true.

    } else {
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        set CLEAR_HUD_VEL to true.
    }
    set DISPLAY_HUD_VEL to (DISPLAY_TAR or DISPLAY_SRF).
    // set AP_NAV_VEL to AP_NAV_VEL + ship:facing*ship:control:pilottranslation.
    // all of the above functions can contribute to setting
    // AP_NAV_VEL, AP_NAV_ACC, AP_NAV_ATT

    if false {
        if HASTARGET {
            set nav_debug_vec_vel to VECDRAW(V(0,0,0), 30*(AP_NAV_VEL-ap_nav_get_vessel_vel(TARGET)), RGB(1,0,1),
                "", 1.0, true, 0.5, true ).
        } else {
            set nav_debug_vec_vel to VECDRAW(V(0,0,0), 30*ap_nav_get_vessel_vel(), RGB(0,1,0),
                "", 1.0, true, 0.5, true ).
        }
        set nav_debug_vec_vel_err to VECDRAW(V(0,0,0), 30*(AP_NAV_VEL-ap_nav_get_vessel_vel()), RGB(1,0,0),
            "", 1.0, true, 0.5, true ).
        set nav_debug_vec_acc to VECDRAW(V(0,0,0), 30*AP_NAV_ACC, RGB(1,1,0),
            "", 1.0, true, 1.0, true ).

        set nav_debug_vec_att0 to VECDRAW(V(0,0,0), 10*AP_NAV_ATT:starvector, RGB(0,0,1),
            "", 1.0, true, 0.125, true ).
        set nav_debug_vec_att1 to VECDRAW(V(0,0,0), 10*AP_NAV_ATT:topvector, RGB(0,0,1),
            "", 1.0, true, 0.125, true ).
        set nav_debug_vec_att2 to VECDRAW(V(0,0,0), 10*AP_NAV_ATT:forevector, RGB(1,1,1),
            "", 1.0, true, 0.125, true ).
    }
}

function ap_nav_wp_done {
    local wp_reached_str is  "reached waypoint " + (util_wp_queue_length()-1).
    print wp_reached_str.
    if defined UTIL_FLDR_ENABLED {
        util_fldr_send_event(wp_reached_str).
    }
    util_wp_done().
    set AP_NAV_TIME_TO_WP to 0.
}

local last_hud_vel is V(0,0,0).
function ap_nav_get_hud_vel {
    if DISPLAY_HUD_VEL {
        set DISPLAY_HUD_VEL to false.
        local orb_srf_vel is ship:geoposition:altitudevelocity(ship:altitude):orbit.
        if ISACTIVEVESSEL {
            if NAVMODE = "TARGET" and HASTARGET {
                set last_hud_vel to AP_NAV_VEL-ap_nav_get_vessel_vel(TARGET).
            } else if NAVMODE = "ORBIT" and AP_NAV_IN_SURFACE {
                set last_hud_vel to AP_NAV_VEL + orb_srf_vel.
            } else if NAVMODE = "SURFACE" and not AP_NAV_IN_SURFACE {
                set last_hud_vel to AP_NAV_VEL - orb_srf_vel.
            } else {
                set last_hud_vel to AP_NAV_VEL.
            }
        }
    }
    if CLEAR_HUD_VEL {
        set CLEAR_HUD_VEL to false.
        set last_hud_vel to V(0,0,0).
    }
    return last_hud_vel.
}

function ap_nav_get_vel_err_mag {
    return ( (AP_NAV_VEL-ap_nav_get_vessel_vel()) + 4*AP_NAV_ACC )*AP_NAV_VEL:normalized.
}

function ap_nav_status_string {
    if DISPLAY_SRF {
        set DISPLAY_SRF to false.
        return ap_nav_srf_status_string().
    }

    if DISPLAY_ORB {
        set DISPLAY_ORB to false.
        return ap_nav_orb_status_string().
    }

    if DISPLAY_TAR {
        set DISPLAY_TAR to false.
        return ap_nav_tar_status_string().
    }
    return "".
}
