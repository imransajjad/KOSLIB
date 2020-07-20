
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

local K_Q is get_param(PARAM,"K_Q").

// NAV GLOBALS
global AP_NAV_TIME_TO_WP is 0.

global AP_NAV_VEL is V(0,0,0).
global AP_NAV_ACC is V(0,0,0).
global AP_NAV_ATT is R(0,0,0).

global AP_NAV_IN_ORBIT is (ship:apoapsis > 20000).
global AP_NAV_IN_SURFACE is (ship:altitude < 36000).

local FOLLOW_MODES is lexicon("F",false,"A",false,"Q",false).

local debug_vectors is false.
if (debug_vectors) { // debug
    clearvecdraws().
    local vec_width is 0.5.
    local vec_scale is 1.0.
    set nav_debug_vec0 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,0),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec1 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,1),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec2 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,0,0),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec3 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,1,1),
                "", vec_scale, true, 0.25*vec_width, true ).
    set nav_debug_vec4 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,0,1),
                "", vec_scale, true, 0.25*vec_width, true ).
    set nav_debug_vec5 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,1),
                "", vec_scale, true, 0.25*vec_width, true ).
    set nav_debug_vec6 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,0,1),
                "", vec_scale, true, 0.25*vec_width, true ).
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
    local head_have is haversine_vec(head_final,vec_final).

    local center_vec is radius*vec_haversine(head_final,list(head_have[0],-90)).

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
    } else {
        set FOLLOW_MODES["F"] to false.
        if (farness-2*sin(head_have[1]) >= 0) {
            set alpha_x to arcsin(((farness-sin(head_have[1])) - farness*cos(head_have[1])*sqrt(1-2/farness*sin(head_have[1])))
                / ( farness^2 -2*farness*sin(head_have[1]) + 1)).
        } else {
            set alpha_x to head_have[1].
        }
    }

    set new_have to list(head_have[0],head_have[1]+alpha_x).
    set c_have to list(head_have[0],head_have[1]+alpha_x-90).


    local new_arc_vector is vec_haversine(head_final,new_have).
    local centripetal_vector is vec_haversine(head_final,c_have).

    local acc_mag is choose frame_vel:mag^2/radius if FOLLOW_MODES["F"] else 0.
    
    set AP_NAV_TIME_TO_WP to vec_final:mag/max(1,frame_vel:mag).


    if debug_vectors {

        local new_have_list is haversine_vec(head_final,new_arc_vector).

        set nav_debug_vec3:start to vec_final.
        set nav_debug_vec3:vec to 10*head_final:vector.
        set nav_debug_vec4:start to vec_final.
        set nav_debug_vec4:vec to 10*head_final:starvector.
        
        // set nav_debug_vec5:start to vec_final.
        // set nav_debug_vec5:vec to center_vec.

        set nav_debug_vec5:start to V(0,0,0).
        set nav_debug_vec5:vec to 10*new_arc_vector.

        set nav_debug_vec6:start to V(0,0,0).
        set nav_debug_vec6:vec to vec_final.
        util_hud_push_right("ap_nav_align", "e:"+round_fig(head_have[0],1) + 
            char(10) + "t:"+round_fig(head_have[1],1) +
            char(10) + "ne:"+round_fig(new_have_list[0],1) + 
            char(10) + "nt:"+round_fig(new_have_list[1],1) +
            char(10) + "ax:"+round_fig(alpha_x,1)).
    }

    return list(new_arc_vector, acc_mag*centripetal_vector).
}


function ap_nav_q_target {
    parameter target_altitude.
    parameter target_vel.
    parameter target_heading.
    parameter target_distance is 99999999999. // assume target is far away
    parameter radius is 0. // a turning radius.

    set FOLLOW_MODES["Q"] to true.

    local sin_max_vangle is 0.5. // sin(30).
    local qtar is simple_q(target_altitude,target_vel).
    local q_simp is simple_q(ship:altitude,ship:airspeed).
    
    set AP_NAV_TIME_TO_WP to target_distance/max(1,ship:airspeed).
    // util_hud_push_right("simple_q_simp", ""+round_dec(q_simp,3)+"/"+round_dec(qtar,3)).

    local elev is arcsin(sat(-K_Q*(qtar-q_simp), sin_max_vangle)).
    set elev to max(elev, -arcsin(min(1.0,ship:altitude/ship:airspeed/5))).

    local elev_diff is deadzone(arctan2(target_altitude-ship:altitude, target_distance+radius),abs(elev)).
    set elev_diff to arctan2(2*tan(elev_diff),1).
    return list(heading(target_heading+elev_diff,elev):vector, V(0,0,0)).
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
            if util_wp_queue_length() = 0 {
                set AP_NAV_VEL to ap_nav_get_vessel_vel().
                set AP_NAV_ACC to V(0,0,0).
                set AP_NAV_ATT to ship:facing.
            }
            set AP_NAV_TIME_TO_WP to 0.
        }
    }
}

function ap_nav_display {

    set AP_NAV_IN_ORBIT to (ship:apoapsis > 20000).
    set AP_NAV_IN_SURFACE to (ship:altitude < 36000).

    if defined UTIL_WP_ENABLED and (util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        if defined AP_NAV_SRF_ENABLED and cur_wayp["mode"] = "srf" {
            ap_nav_srf_wp_guide(cur_wayp).
            if (debug_vectors) {
                set nav_debug_vec0:vec to AP_NAV_VEL.
                set nav_debug_vec1:vec to AP_NAV_ACC.
                set nav_debug_vec2:vec to 30*(AP_NAV_VEL-ap_nav_get_vessel_vel()).
            }
        } else if defined AP_NAV_ORB_ENABLED and cur_wayp["mode"] = "orb" {
            ap_nav_orb_wp_guide(cur_wayp).
        } else if defined AP_NAV_TAR_ENABLED and cur_wayp["mode"] = "tar" {
            ap_nav_tar_wp_guide(cur_wayp).
            if (debug_vectors) {
                if HASTARGET {
                    set nav_debug_vec0:vec to 30*(AP_NAV_VEL-ap_nav_get_vessel_vel(TARGET)).
                }
                set nav_debug_vec1:vec to AP_NAV_ACC.
                set nav_debug_vec2:vec to 30*(AP_NAV_VEL-ap_nav_get_vessel_vel()).
            }
        } else {
            print "got unsupported wp, marking it done".
            util_wp_done().
        }
    } else if defined AP_NAV_ORB_ENABLED and AP_NAV_IN_ORBIT {
        ap_nav_orb_stick().
    } else if defined AP_NAV_SRF_ENABLED and AP_NAV_IN_SURFACE {
        ap_nav_srf_stick().
    } else {
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
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
    if AP_NAV_IN_SURFACE {
        return this_vessel:velocity:surface.
    } else {
        return this_vessel:velocity:orbit.
    }
}

function ap_nav_get_time_to_wp {
    return round(min(9999,AP_NAV_TIME_TO_WP)).
}

local vel_displayed is 0.
function ap_nav_status_string {
    local dstr is "".
    if defined AP_NAV_SRF_ENABLED and AP_NAV_IN_SURFACE {
        set dstr to dstr+ap_nav_srf_status_string().
    }
    if defined AP_NAV_ORB_ENABLED and AP_NAV_IN_ORBIT {
        set dstr to dstr+ap_nav_orb_status_string().
    }
    if defined AP_NAV_TAR_ENABLED {
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
        set nav_debug_vec2:show to true.
        set nav_debug_vec3:show to true.
        set nav_debug_vec4:show to true.
        set nav_debug_vec5:show to true.
        set nav_debug_vec6:show to true.
    }

    return dstr.
}
