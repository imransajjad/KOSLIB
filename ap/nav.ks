
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

local K_Q is get_param(PARAM,"K_Q").

global AP_NAV_TIME_TO_WP is 0.

global AP_NAV_VEL is V(0,0,0).
global AP_NAV_ACC is V(0,0,0).
global AP_NAV_ATT is R(0,0,0).

global lock in_orbit to (ship:apoapsis > 20000).
global lock in_surface to (ship:altitude < 36000).
global lock in_docking to false. //(HASTARGET and target:distance < DOCK_DISTANCE).

local FOLLOW_MODES is lexicon("F",false,"A",false,"Q",false).

local USE_UTIL_WP is false.
local SRF_ENABLED is false.
local ORB_ENABLED is false.
local TAR_ENABLED is false.

local debug_vectors is false.
if (debug_vectors) { // debug
    clearvecdraws().
    local vec_width is 0.5.
    local vec_scale is 1.0.
    set nav_debug_vec0 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,0),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec1 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,1),
                "", vec_scale, true, vec_width, true ).
}

// helper functions for other NAV files

// returns a unit vector for velocity direction
// returns a vector for angular velocity in degrees per second
// both in ship raw frame
local on_circ_feedforward is false.
function ap_nav_align {
    parameter vec_final. // position vector to target
    parameter head_final. // desired heading upon approach
    parameter frame_vel. // a velocity vector in this frame
    parameter radius. // a turning radius.

    set FOLLOW_MODES["A"] to true.
    local alpha_x is 0.
    local head_have is haversine_dir((-head_final)*vec_final:direction).

    local center_vec is radius*
        (head_final*dir_haversine(list(head_have[0],-90,head_have[2]))):vector.

    local farness is vec_final:mag/radius.
    local to_circ is (vec_final+center_vec):normalized*frame_vel:normalized.
    local in_circ is (farness^2)/max(0.00001,2-2*cos(2*head_have[1])).

    if (to_circ <= 0.00) and (in_circ < 2) {
        set on_circ_feedforward to true.
    } else if (in_circ > 2) and (farness > 2 ) {
        set on_circ_feedforward to false.
    }

    if on_circ_feedforward {
        set FOLLOW_MODES["F"] to true.
        set alpha_x to head_have[1].
        // util_hud_push_right("nav_srf", "head_have[1]").
    } else {
        set FOLLOW_MODES["F"] to false.
        if (farness-2*sin(head_have[1]) >= 0) {
            set alpha_x to arcsin(((farness-sin(head_have[1])) - farness*cos(head_have[1])*sqrt(1-2/farness*sin(head_have[1])))
                / ( farness^2 -2*farness*sin(head_have[1]) + 1)).
        } else {
            set alpha_x to head_have[1].
        }
    }

    set new_have to list(head_have[0],head_have[1]+alpha_x, head_have[2]).
    set c_have to list(head_have[0],head_have[1]+alpha_x-90, head_have[2]).

    local new_arc_direction is head_final*dir_haversine(new_have).
    local centripetal_vector is head_final*dir_haversine(c_have):vector.

    local acc_mag is choose frame_vel:mag^2/radius if FOLLOW_MODES["F"] else 0.
    
    return list(new_arc_direction:vector, acc_mag*centripetal_vector).
}


function ap_nav_q_target {
    parameter target_altitude.
    parameter target_vel.
    parameter target_heading.

    set FOLLOW_MODES["Q"] to true.

    local sin_max_vangle is 0.5. // sin(30).
    local qtar is simple_q(target_altitude,target_vel).
    local q_simp is simple_q(ship:altitude,ship:airspeed).

    // util_hud_push_right("simple_q_simp", ""+round_dec(q_simp,3)+"/"+round_dec(qtar,3)).

    local elev is arcsin(sat(-K_Q*(qtar-q_simp), sin_max_vangle)).
    set elev to max(elev, -arcsin(min(1.0,ship:altitude/ship:airspeed/5))).
    return list(heading(target_heading,elev):vector, V(0,0,0)).
}

function ap_nav_check_done {
    parameter vec_final. // position vector to target
    parameter head_final. // desired heading upon approach
    parameter frame_vel. // a velocity vector in this frame
    parameter radius. // a turning radius.

    local time_dir is frame_vel*vec_final:normalized.
    local time_to is vec_final:mag/max(frame_vel:mag,0.0001).

    if (time_to < 3) {
        local angle_to is vectorangle(vec_final,frame_vel).

        if ( angle_to > 30) or
            (angle_to > 12.5 and time_to < 2) or 
            ( time_to < 1) {
            local wp_reached_str is  "Reached Waypoint " + (util_wp_queue_length()-1).
            print wp_reached_str.
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event(wp_reached_str).
            }
            util_wp_done().
            set AP_NAV_TIME_TO_WP to 0.
        }
    }
}

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

    if USE_UTIL_WP and (util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        if SRF_ENABLED and cur_wayp["mode"] = "srf" {
            local nav_data is ap_nav_srf_wp_guide(cur_wayp).
            set AP_NAV_VEL to nav_data[0].
            set AP_NAV_ACC to nav_data[1].
            set AP_NAV_ATT to nav_data[2].
            if (debug_vectors) {
                set nav_debug_vec0:vec to AP_NAV_VEL.
                set nav_debug_vec1:vec to AP_NAV_ACC.
            }
        } else if ORB_ENABLED and cur_wayp["mode"] = "orb" {
            local nav_data is ap_nav_orb_wp_guide(cur_wayp).
            set AP_NAV_VEL to nav_data[0].
            set AP_NAV_ACC to nav_data[1].
            set AP_NAV_ATT to nav_data[2].
        } else if TAR_ENABLED and cur_wayp["mode"] = "tar" {
            local nav_data is ap_nav_tar_wp_guide(cur_wayp).
            set AP_NAV_VEL to nav_data[0].
            set AP_NAV_ACC to nav_data[1].
            set AP_NAV_ATT to nav_data[2].
            if (debug_vectors) {
                set nav_debug_vec0:vec to 30*(AP_NAV_VEL-ship:velocity:orbit).
                if hasTarget {
                    set nav_debug_vec1:vec to 30*(AP_NAV_VEL-ap_nav_get_vessel_vel(TARGET)).
                }
            }
        } else {
            print "got unsupported wp, marking it done".
            util_wp_done().
        }
    } else {
        if SRF_ENABLED and in_surface {
            ap_nav_srf_stick().
        }
        if ORB_ENABLED and in_orbit {
            local nav_data is ap_nav_orb_stick().
            set AP_NAV_VEL to nav_data[0].
            set AP_NAV_ACC to nav_data[1].
            set AP_NAV_ATT to nav_data[2].
        }
        // if TAR_ENABLED and in_docking {
        //     ap_nav_tar_stick().
        // }
    }
    set AP_NAV_VEL to AP_NAV_VEL + ship:facing*ship:control:pilottranslation.
    // all of the above functions can contribute to setting
    // AP_NAV_VEL, AP_NAV_ACC, AP_NAV_ATT
}

function ap_nav_get_direction {
    local py_temp is pitch_yaw_from_dir(AP_NAV_VEL:direction).
    return heading(py_temp[1],py_temp[0]).
}

function ap_nav_get_vel {
    return AP_NAV_VEL.
}

function ap_nav_overwrite_vel {
    parameter vec_in.
    set AP_NAV_VEL to vec_in.
}

function ap_nav_get_vel_err_mag {
    return (AP_NAV_VEL:mag-ap_nav_get_vessel_vel():mag).
}

function ap_nav_get_vessel_vel {
    parameter this_vessel is ship.
    if not this_vessel:hassuffix("velocity") {
        set this_vessel to this_vessel:ship.
    }
    if (ship:altitude < 36000) {
        return this_vessel:velocity:surface.
    } else {
        return this_vessel:velocity:orbit.
    }
}

function ap_nav_get_time_to_wp {
    return round(min(9999,AP_NAV_TIME_TO_WP)).
}

function ap_nav_do {
    // NAV_V, NAV_PRO, NAV_FACE, NAV_A, NAV_W_PRO, NAV_W_FACE
    // are used by these functions
    if SRF_ENABLED and (in_surface or (not ORB_ENABLED and in_orbit)) {
        if defined AP_AERO_ROT_ENABLED {
            ap_aero_rot_nav_do(AP_NAV_VEL,AP_NAV_ACC,AP_NAV_ATT).
        }
        if defined AP_AERO_ENGINES_ENABLED {
            ap_aero_engine_throttle_auto(AP_NAV_VEL).
        }
    } else if ORB_ENABLED and (in_orbit or (not SRF_ENABLED and in_surface)) {
        if defined AP_ORB_ENABLED {
            ap_orb_nav_do(AP_NAV_VEL,AP_NAV_ACC,AP_NAV_ATT).
        }
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

    local mode_str is "".
    for k in FOLLOW_MODES:keys {
        if FOLLOW_MODES[k] {
            set mode_str to mode_str+k.
            set FOLLOW_MODES[k] to false.
        }
    }
    set dstr to dstr + (choose "" if mode_str = "" else char(10)+mode_str).
    if (debug_vectors) {
        set nav_debug_vec0:show to true.
        set nav_debug_vec1:show to true.
    }

    return dstr.
}
