
// required module AP_MODE_ENABLED
GLOBAL AP_NAV_ENABLED IS TRUE.
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED AP_MODE_ENABLED) { GLOBAL AP_MODE_ENABLED IS false.}


// required global, will not modify
// roll, pitch, yaw
// vel
// vel_pitch, vel_bear
// pilot_input_u0, pilot_input_u1, pilot_input_u2, pilot_input_u3


local AP_NAV_VERT_G is 0.1.
local AP_NAV_HOR_G is 1.0.

local VSET_MAN is FALSE.
local PSET_MAN is FALSE.
local HSET_MAN is FALSE.

local V_SET_PREV is -1.0.
local V_SET is -1.0.
local P_SET is 0.0.
local R_SET is 0.0.
local H_SET is 90.0.

local H_CLOSE is false.
local WP_ARC is false.

local W_VERT_SET is 0.0.
local W_HOR_SET is 0.0.


IF SHIP:AIRSPEED > 1.0 {
    set V_SET_PREV to vel.
    set V_SET to vel.
    set P_SET to vel_pitch.
    set H_SET to vel_bear.
    set R_SET to 0.0.
}

local real_geodistance is 0.0.

local lock DELTA_ROTATION to R(0,0,roll)*(-SHIP:SRFPROGRADE)*(HEADING(H_SET, P_SET)).

FUNCTION ap_nav_do_flcs_rot {


    local head_error is wrap_angle_until(H_SET - vel_bear).

    local have_roll_pitch is haversine(vel_pitch,vel_bear,P_SET,H_SET).

    local roll_w is outerweight(have_roll_pitch[1], AP_NAV_ROLL_W_MIN, AP_NAV_ROLL_W_MAX).

    local roll_target is R_SET + 
        roll_w*wrap_angle_until(have_roll_pitch[0]) +
        (1-roll_w)*sat( AP_NAV_K_HEADING*head_error, AP_NAV_BANK_MAX).

    ap_flcs_rot(
    sat(AP_NAV_K_PITCH*wrap_angle_until(-DELTA_ROTATION:pitch) + W_VERT_SET,1.0),
    sat(AP_NAV_K_YAW*wrap_angle_until(DELTA_ROTATION:yaw),1.0) + W_HOR_SET,
    sat(AP_NAV_K_ROLL*(roll_target - roll), 1.0)
    ).
}


function ap_nav_do_flcs_g {
    // target_a is an acceleration in ground frame (nav frame)
    parameter target_a.

    
    local a_intrinsic is -g0*ship:up. // add centrifugal/coriolis forces here.
    set target_a to target_a - a_intrinsic.

    local roll_target is 0.0.

    ap_flcs_rot(
        sat(target_a*ship:facing:upvector/vel, AP_NAV_ROT_GLIM_VERT),
        sat(target_a*ship:facing:starvector/vel, AP_NAV_ROT_GLIM_LAT),
        sat(AP_NAV_K_ROLL*(roll_target - roll), 1.0)
        ).
}

FUNCTION ap_nav_disp {
    // for waypoint in waypoint_queue, set pitch, heading to waypoint, ELSE
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

    set PSET_MAN to false.
    set HSET_MAN to false.
    set VSET_MAN to false.

    set V_SET_PREV to V_SET.

    IF (UTIL_WP_ENABLED and util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        set V_SET to cur_wayp[1].


        // climb/descend to target altitude
        if cur_wayp:length = 3 or cur_wayp:length = 4 {

            local max_vangle is 30.

            local max_vturn is AP_NAV_VERT_G/vel.

            local linear_climb_boundary is (max(vel,1.0)^2)/(AP_NAV_VERT_G*g0)*(1-cos(max_vangle)).
            //set local_climb_boundary to 0.1*level_radius.
            //set local_gain to arccos(1-abs(local_climb_boundary)/level_radius)/local_climb_boundary.
            local hdiff is cur_wayp[0] - ship:ALTITUDE.

            if abs(hdiff) < linear_climb_boundary {
                set H_CLOSE to true.
                set W_VERT_SET to -(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
                set P_SET to RAD2DEG*sqrt(abs(hdiff)*AP_NAV_VERT_G*g0)/(max(vel,1.0))*sat(hdiff,1.0).
            } else {
                set H_CLOSE to false.
                set W_VERT_SET to +(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
                set P_SET to 0.95*pitch.
                if (pitch > max_vangle and W_VERT_SET > 0) or 
                    (pitch < -max_vangle and W_VERT_SET < 0){
                        set W_VERT_SET to 0.
                        set P_SET to sat(pitch,max_vangle).
                }
            }



            //if abs(hdiff) > linear_climb_boundary {
            //    set P_SET to max_climb*sat(hdiff,1).
            //    set P_SET to vel_pitch+sat(P_SET-vel_pitch, 3.0).
            //} else if abs(hdiff) > local_climb_boundary {
            //    set P_SET to arccos(1-abs(hdiff)/level_radius)*sat(hdiff,1).
            //} else {
            //    set P_SET to local_gain*hdiff.
            //    // still haven't dealt with coriolis+centrifugal force
            //}
        }
        
        // set roll and heading targets
        if cur_wayp:length = 3 {
            // altitude, velocity, delta_heading

            set H_SET to vel_bear.
            set R_SET to cur_wayp[2].

        } else if cur_wayp:length = 4 {
            // altitude, velocity, lat, long
            set geo_target to LATLNG(cur_wayp[2],cur_wayp[3]).
            set H_SET to geo_target:HEADING.

            set R_SET to 0.
            // still haven't dealt with coriolis force
        }

        // set everything if waypoint has target orientation
        if cur_wayp:length = 6 {
            // altitude, velocity, lat, long, final_pitch, final_heading
            local wp_vec is LATLNG(cur_wayp[2],cur_wayp[3]):altitudeposition(cur_wayp[0]).
            local wp_final_head is heading(cur_wayp[5],cur_wayp[4]).
            local current_vel_head is heading(vel_bear,vel_pitch).

            // find center of turn circle
            local final_radius is max(50,cur_wayp[1]^2)/(AP_NAV_ROT_GNOM_VERT*g0).
            local center_target is wp_vec-final_radius*wp_final_head:starvector.
            local center_target_right is wp_vec+final_radius*wp_final_head:starvector.

            local inter_radius is max(50,cur_wayp[1]^2)/(AP_NAV_ROT_GNOM_VERT*g0).
            local current_center is -inter_radius*current_vel_head:starvector.

            if center_target_right:mag < center_target:mag {
                set center_target to center_target_right.
                set current_center to final_radius*current_vel_head:starvector.
            }

            //set WP_ARC to ((vectorangle(center_target-current_center,ship:SRFPROGRADE:vector) > 30) or
                        //(center_target-current_center):mag/(ship:SRFPROGRADE:vector*(center_target-current_center)/(center_target-current_center):mag) < 1.5).

            //set WP_ARC to ( wp_vec*wp_final_head:vector > 0 and wp_vec:mag < 3*inter_radius).

            if not WP_ARC {
                set WP_ARC to (center_target*current_vel_head:vector < 0).
            }

            if WP_ARC {
                set rot_mat to rotatefromto(wp_final_head:vector,wp_vec).
                set guide_dir to rot_mat*rot_mat*wp_final_head.
                set guide_dir_py to R(90,0,0)*(-SHIP:UP)*guide_dir.
                set P_SET to (mod(guide_dir_py:pitch+90,180)-90).
                set H_SET to (360-guide_dir_py:yaw).
                set R_SET to 0.
            } else {
                //print "ofs "+ round((center_target-current_center):mag).
                set guide_dir to (center_target-current_center):direction.
                set guide_dir_py to R(90,0,0)*(-SHIP:UP)*guide_dir.
                set P_SET to (mod(guide_dir_py:pitch+90,180)-90).
                set H_SET to (360-guide_dir_py:yaw).
                set R_SET to 0.
            }

            

        }

        // if waypoint has any form of destination
        if cur_wayp:length > 3 {

            local geo_target is LATLNG(cur_wayp[2],cur_wayp[3]).
            local DIRECT_DISTANCE is geo_target:altitudeposition(cur_wayp[0]):MAG.
            local wp_vec is LATLNG(cur_wayp[2],cur_wayp[3]):altitudeposition(cur_wayp[0]).

            local arc_radius is (ship:body:radius+ship:altitude).
            set real_geodistance TO
                2*arc_radius*DEG2RAD*ARCSIN(DIRECT_DISTANCE/2/arc_radius).

            IF (real_geodistance/vel < 3) {
                if ( vectorangle(wp_vec,ship:velocity:surface) > 30)
                        or (real_geodistance/vel < 1.5){
                    print "dist " + round_dec(wp_vec:mag,2).
                    PRINT "Reached Waypoint " + util_wp_queue_length().
                    util_wp_done().
                    set WP_ARC to false.
                }
            }
        }
    }
    ELSE {
        set W_VERT_SET to 0.0.
        set W_HOR_SET to 0.0.
        IF AP_FLCS_CHECK() {
            SET P_SET TO vel_pitch.
            SET H_SET TO vel_bear.
            SET V_SET TO vel.
        } ELSE IF AP_VEL_CHECK() {
            SET P_SET TO vel_pitch.
            SET H_SET TO vel_bear.
            SET VSET_MAN TO TRUE.
        } ELSE IF AP_NAV_CHECK() {
            SET PSET_MAN TO TRUE.
            SET HSET_MAN TO TRUE.
            SET VSET_MAN TO TRUE.
        }
        set real_geodistance to 0.0.
    }

    IF VSET_MAN AND is_active_vessel() {
        SET INC TO 2.7*deadzone(2*pilot_input_u0-1,0.1).
        IF INC <> 0 {
            SET V_SET To MIN(MAX(V_SET+INC,-1),1000).
            //vec_info_draw().
        }
    }
    IF PSET_MAN{
        SET INC TO 2.0*deadzone(pilot_input_u1,0.25).
        IF INC <> 0 {
            SET P_SET To sat(P_SET + INC, 90).
            //vec_info_draw().
        }
    }
    IF HSET_MAN{
        SET INC TO 4.0*deadzone(pilot_input_u3,0.25).
        IF INC <> 0 {
            SET H_SET To wrap_angle_until(H_SET + INC).
            //vec_info_draw().
        }
    }
}

function ap_nav_get_data {
    return list(V_SET,H_SET,P_SET,R_SET).
}

function ap_nav_get_direction {
    return heading(H_SET,P_SET).
}

function ap_nav_get_head {
    return H_SET.
}

function ap_nav_get_pitch {
    return P_SET.
}

function ap_nav_get_vel {
    return V_SET.
}

function ap_nav_get_roll {
    return R_SET.
}

function ap_nav_get_distance {
    return real_geodistance.
}

function ap_nav_status_string {
    local vs_string is "".
    if not AP_FLCS_CHECK() {
        set vs_string to "/"+round_dec(V_SET,0).
        if (V_SET_PREV < V_SET){
            set vs_string to vs_string + "+".
        } else if (V_SET_PREV > V_SET){
            set vs_string to vs_string + "-".
        }
    }
    return ""+vs_string+ 
    (choose char(10)+"["+round_dec(P_SET,2)+","+round(H_SET)+"]" +
        char(10)+"["+round_dec(W_VERT_SET,3)+","+round_dec(W_HOR_SET,3)+","+H_CLOSE +"]"
        if AP_NAV_CHECK() else "") + char(10)+ ( choose "WP_ARC" if WP_ARC else "WP_HEAD").
}
