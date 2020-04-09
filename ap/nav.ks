
GLOBAL AP_NAV_ENABLED IS TRUE.

// required global, will not modify
// roll, pitch, yaw
// vel
// vel_pitch, vel_bear
// pilot_input_u0, pilot_input_u1, pilot_input_u2, pilot_input_u3

local lock AG to AG3.

local USE_WP is (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED.
local USE_GCAS is (defined AP_NAV_GCAS_ENABLED) and AP_NAV_GCAS_ENABLED.

local AP_NAV_VERT_G is 0.1.
local AP_NAV_HOR_G is 1.0.

local lock W_PITCH_NOM to max(50,vel)/(g0*AP_NAV_ROT_GNOM_VERT).
local lock W_YAW_NOM to max(50,vel)/(g0*AP_NAV_ROT_GNOM_LAT).

local VSET_MAN is FALSE.
local ESET_MAN is FALSE.
local HSET_MAN is FALSE.

local V_SET_PREV is -1.0.
local V_SET is -1.0.
local E_SET is 0.0.
local R_SET is 0.0.
local H_SET is 90.0.

local H_CLOSE is false.
local WP_FOLLOW_MODE is 0.
local WP_FOLLOW_MODE_STRS is list("NAV_ARC", "NAV_Q").

local W_PITCH_SET is 0.0.
local W_YAW_SET is 0.0.

IF vel > 1.0 {
    set V_SET_PREV to vel.
    set V_SET to vel.
    set E_SET to vel_pitch.
    set H_SET to vel_bear.
    set R_SET to 0.0.
}

local real_geodistance is 0.0.

local vec_scale is 1.0.
local vec_width is 2.0.

if (false) { // debug
    set nav_debug_vec0 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,0),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec1 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,1),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec2 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,0,1),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec3 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,1,0),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec4 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,1,1),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec5 to VECDRAW(V(0,0,0), V(0,0,0), RGB(1,1,1),
                "", vec_scale, true, vec_width, true ).
    set nav_debug_vec6 to VECDRAW(V(0,0,0), V(0,0,0), RGB(0,0,0),
                "", vec_scale, true, vec_width, true ).
}

FUNCTION ap_nav_do_flcs_rot {

    local head_error is wrap_angle_until(H_SET - vel_bear).
    local pitch_error is wrap_angle_until(E_SET - vel_pitch).

    local have_roll_pitch is haversine(vel_pitch,vel_bear,E_SET,H_SET).
    local roll_w is outerweight(have_roll_pitch[1], AP_NAV_ROLL_W_MIN, AP_NAV_ROLL_W_MAX).
    local roll_target is R_SET + 
        roll_w*wrap_angle_until(have_roll_pitch[0]) +
        (1-roll_w)*sat( AP_NAV_K_HEADING*head_error, AP_NAV_BANK_MAX).
    if ship:status = "LANDED" {
        set roll_target to 0.
    }

    if USE_GCAS and GCAS_ACTIVE {
        ap_flcs_rot(
        AP_NAV_GCAS_GAIN_MULTIPLIER*AP_NAV_K_PITCH*(cos(roll)*pitch_error + sin(roll)*head_error) + cos(roll)*W_PITCH_SET  + sin(roll)*W_YAW_SET,
        AP_NAV_GCAS_GAIN_MULTIPLIER*AP_NAV_K_YAW*(-sin(roll)*pitch_error + cos(roll)*head_error) - sin(roll)*W_PITCH_SET + cos(roll)*W_YAW_SET,
        AP_NAV_GCAS_GAIN_MULTIPLIER*AP_NAV_K_ROLL*(roll_target - roll),
        true ).
    } else {
        ap_flcs_rot(
        sat(AP_NAV_K_PITCH*(cos(roll)*pitch_error + sin(roll)*head_error) + cos(roll)*W_PITCH_SET  + sin(roll)*W_YAW_SET, 2.0*W_PITCH_NOM),
        sat(AP_NAV_K_YAW*(-sin(roll)*pitch_error + cos(roll)*head_error) - sin(roll)*W_PITCH_SET + cos(roll)*W_YAW_SET, 2.0*W_YAW_NOM),
        AP_NAV_K_ROLL*(roll_target - roll),
        true ).
    }
}

// does maneuver nodes in spaceflight when they are encountered
function ap_nav_do_man {
    return.
}

local GCAS_ARMED is false.
local GCAS_ACTIVE is false.
local straight_vector is V(0,0,0).
local impact_vector is V(0,0,0).
local impact_alt is 0.

function ap_nav_gcas {
    // ground collision avoidance system
    local escape_pitch is 10.
    local sticky_factor is 2.0.
    local react_time is 1.0.


    if not GEAR and not SAS {
        local rates is ap_flcs_rot_maxrates().
        set rates[0] to max(rates[0]/1.0,1.0).
        set rates[1] to max(rates[1],1.0).
        set rates[2] to max(rates[2]/6.0,1.0).

        local t_preroll is abs(roll/rates[2]) + react_time.
        local t_pitch is 2*abs((escape_pitch-vel_pitch)/rates[0]).
        local vel_pitch_up is min(90,max(0,-vel_pitch)).

        set straight_vector to
                ship:srfprograde:forevector*( (t_pitch + t_preroll)*vel ).
        set impact_vector to 
                ship:srfprograde:forevector*( RAD2DEG*vel/rates[0]*sin(vel_pitch_up) + t_preroll*vel ) +
                ship:srfprograde:topvector*( RAD2DEG*vel/rates[0]*(1-cos(vel_pitch_up))).

        if not GCAS_ARMED {
            if (ship:altitude+straight_vector*ship:up:vector-AP_NAV_GCAS_MARGIN <
                    max(ship:geoposition:terrainheight,0)) {
                util_hud_push_right("NAV_GCAS", "GCAS").
                print "GCAS armed".
                set GCAS_ARMED to true.
            }
        } else if GCAS_ARMED {

            local impact_distance is impact_vector*heading(vel_bear,0):vector.
            local impact_longitude is ship:geoposition:lng+RAD2DEG*impact_distance/ship:body:radius*sin(vel_bear).
            local impact_latitude is ship:geoposition:lat+RAD2DEG*impact_distance/ship:body:radius*cos(vel_bear).

            set impact_alt to max(latlng(impact_latitude,impact_longitude):terrainheight,0).

            if not GCAS_ACTIVE and (ship:altitude+impact_vector*ship:up:vector-AP_NAV_GCAS_MARGIN < impact_alt ) {
                // GCAS is active here, will put in NAV mode after setting headings etc
                set GCAS_ACTIVE to true.
                util_hud_push_right("NAV_GCAS", "GCAS"+char(10)+"ACTIVE").
                print "GCAS ACTIVE".
                ap_mode_set("NAV").

            } else if GCAS_ACTIVE and not (ship:altitude+impact_vector*ship:up:vector-sticky_factor*AP_NAV_GCAS_MARGIN < impact_alt ) {
                ap_mode_set("FLCS").
                print "GCAS INACTIVE".
                util_hud_pop_right("NAV_GCAS").
                set GCAS_ACTIVE to false.
            }

            if GCAS_ACTIVE {
                set E_SET to escape_pitch.
                set H_SET to vel_bear.
                set R_SET to 0.
                set W_PITCH_SET to 0*DEG2RAD*rates[0].
                set W_YAW_SET to 0.
                set V_SET to AP_NAV_VSET_MAX.

                if (ship:altitude - AP_NAV_GCAS_MARGIN < max(ship:geoposition:terrainheight,0))
                {
                    print "GCAS FLOOR BREACHED".
                    util_hud_push_right("NAV_GCAS", "GCAS"+char(10)+"BREACHED").
                }
            }

            if not GCAS_ACTIVE and not (ship:altitude+straight_vector*ship:up:vector-AP_NAV_GCAS_MARGIN < 
                    max(ship:geoposition:terrainheight,0)) {
                util_hud_pop_right("NAV_GCAS").
                print "GCAS disarmed".
                set GCAS_ARMED to false.
            }
        }
    } else if GCAS_ARMED or GCAS_ACTIVE {
        // if GEAR or SAS, undo everything
        ap_mode_set("FLCS").
        util_hud_pop_right("NAV_GCAS").
        set GCAS_ARMED to false.
        set GCAS_ACTIVE to false.
    }
    return GCAS_ACTIVE.
}


local arc_have is list(0,0,0).
local head_have is list(0,0,0).
local new_have is list(0,0,0).
local outer_circle_flip is 0.
local closeness is 1.0.

function ap_nav_disp {
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

    if (USE_GCAS) and ap_nav_gcas(){
        return.
    }

    set ESET_MAN to false.
    set HSET_MAN to false.
    set VSET_MAN to false.

    set V_SET_PREV to V_SET.

    IF USE_WP and (util_wp_queue_length() > 0) {
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
                set W_PITCH_SET to -(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
                set E_SET to RAD2DEG*sqrt(abs(hdiff)*AP_NAV_VERT_G*g0)/(max(vel,1.0))*sat(hdiff,1.0).
            } else {
                set H_CLOSE to false.
                set W_PITCH_SET to +(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
                set E_SET to 0.95*pitch.
                if (pitch > max_vangle and W_PITCH_SET > 0) or 
                    (pitch < -max_vangle and W_PITCH_SET < 0){
                        set W_PITCH_SET to 0.
                        set E_SET to sat(pitch,max_vangle).
                }
            }



            //if abs(hdiff) > linear_climb_boundary {
            //    set E_SET to max_climb*sat(hdiff,1).
            //    set E_SET to vel_pitch+sat(E_SET-vel_pitch, 3.0).
            //} else if abs(hdiff) > local_climb_boundary {
            //    set E_SET to arccos(1-abs(hdiff)/level_radius)*sat(hdiff,1).
            //} else {
            //    set E_SET to local_gain*hdiff.
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

            set WP_FOLLOW_MODE to 0.

            local bear_to_final is rotatefromto(wp_final_head:vector,wp_vec).
            set arc_have to haversine_dir(bear_to_final*bear_to_final*wp_final_head,wp_final_head).
            set head_have to haversine_dir(bear_to_final*wp_final_head,wp_final_head).
            
            local large_radius is abs(wp_vec:mag/2/cos(90-arc_have[1]/2)).
            local final_radius is max(50,cur_wayp[1]^2)/(AP_NAV_ROT_GNOM_VERT*g0).
            set closeness to (final_radius/large_radius)^2.

            set outer_circle_flip to (choose 1 if (vdot(wp_vec,wp_final_head:vector) < 0) else 0).
            if outer_circle_flip = 1 {
                set new_have to list( head_have[0]-180, ((1-closeness)*(head_have[1]) + closeness*wrap_angle_until(arc_have[1])), 0 ).
            } else {
                set new_have to list( head_have[0]-180, ((1-closeness)*head_have[1] + closeness*wrap_angle_until(arc_have[1])), 0 ).
            }
            
            local new_arc_direction is wp_final_head*dir_haversine(new_have).

            local centripetal_vector is angleaxis(arc_have[0]-180-180*outer_circle_flip,new_arc_direction:vector)*current_vel_head:topvector.

            if (false) { // debug
                set nav_debug_vec0:vec to 30*centripetal_vector.
                set nav_debug_vec1:vec to 100*(bear_to_final*bear_to_final*wp_final_head):vector.
                set nav_debug_vec2:vec to 100*(bear_to_final*wp_final_head):vector.
                set nav_debug_vec3:vec to 100*new_arc_direction:vector.
                set test_have to list(135,45,0).
                //set nav_debug_vec1:vec to 100*dir_haversine(new_have):starvector.
                //set nav_debug_vec2:vec to 100*dir_haversine(new_have):topvector.
                //set nav_debug_vec3:vec to 100*dir_haversine(new_have):vector.
                local ship_raw is R(0,0,0).

                set nav_debug_vec4:vec to 30*wp_final_head:starvector.
                set nav_debug_vec5:vec to 30*wp_final_head:topvector.
                set nav_debug_vec6:vec to 30*wp_final_head:vector.
                
                set nav_debug_vec0:show to true.
                set nav_debug_vec1:show to true.
                set nav_debug_vec2:show to true.
                set nav_debug_vec3:show to true.
                set nav_debug_vec4:show to true.
                set nav_debug_vec5:show to true.
                set nav_debug_vec6:show to true.
            }

            local py_temp is pitch_yaw_from_dir(new_arc_direction).
            set E_SET to py_temp[0].
            set H_SET to py_temp[1].
            set R_SET to 0.
            //set W_PITCH_SET to max(50,vel)/large_radius*(current_vel_head:topvector*centripetal_vector).
            //set W_YAW_SET to max(50,vel)/large_radius*(current_vel_head:starvector*centripetal_vector).
            //print " " + round_dec(W_PITCH_SET,5) + "/" + round_dec(W_YAW_SET,5).
        }

        // if waypoint has any form of destination
        if cur_wayp:length > 3 {

            local geo_target is LATLNG(cur_wayp[2],cur_wayp[3]).
            local DIRECT_DISTANCE is geo_target:altitudeposition(cur_wayp[0]):MAG.
            local wp_vec is LATLNG(cur_wayp[2],cur_wayp[3]):altitudeposition(cur_wayp[0]).

            local arc_radius is (ship:body:radius+ship:altitude).
            set real_geodistance TO
                arc_radius*DEG2RAD*haversine(ship:geoposition:lat,ship:geoposition:lng, cur_wayp[2],cur_wayp[3])[1].

            IF (real_geodistance/vel < 3) {
                if ( vectorangle(wp_vec,ship:velocity:surface) > 30)
                        or (real_geodistance/vel < 1.5){
                    print "dist " + round_dec(wp_vec:mag,2).
                    PRINT "Reached Waypoint " + util_wp_queue_length().
                    util_wp_done().
                    if util_wp_queue_length() = 0 {
                        SET E_SET TO vel_pitch.
                        SET H_SET TO vel_bear.
                        SET V_SET TO vel.
                    }
                }
            }
        }
    }
    ELSE {
        set W_PITCH_SET to 0.0.
        set W_YAW_SET to 0.0.
        IF AP_FLCS_CHECK() {
            SET E_SET TO vel_pitch.
            SET H_SET TO vel_bear.
            SET V_SET TO vel.
        } ELSE IF AP_VEL_CHECK() {
            SET E_SET TO vel_pitch.
            SET H_SET TO vel_bear.
            SET VSET_MAN TO TRUE.
        } ELSE IF AP_NAV_CHECK() {
            SET ESET_MAN TO TRUE.
            SET HSET_MAN TO TRUE.
            SET VSET_MAN TO TRUE.
        }
        set real_geodistance to 0.0.
    }

    IF VSET_MAN AND is_active_vessel() {
        SET INC TO 2.7*deadzone(2*pilot_input_u0-1,0.1).
        IF INC <> 0 {
            SET V_SET To MIN(MAX(V_SET+INC,-1),AP_NAV_VSET_MAX).
            //vec_info_draw().
        }
    }
    IF ESET_MAN {
        SET INC TO 2.0*deadzone(pilot_input_u1,0.25).
        IF INC <> 0 {
            SET E_SET To sat(E_SET + INC, 90).
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
    return list(V_SET,H_SET,E_SET,R_SET).
}

function ap_nav_get_direction {
    return heading(H_SET,E_SET).
}

function ap_nav_get_head {
    return H_SET.
}

function ap_nav_get_elev {
    return E_SET.
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
    if AP_MODE_NAV or AP_MODE_VEL {
        set vs_string to "/"+round_dec(V_SET,0).
        if (V_SET_PREV < V_SET){
            set vs_string to vs_string + "+".
        } else if (V_SET_PREV > V_SET){
            set vs_string to vs_string + "-".
        }      
    }
    if AP_MODE_NAV {
        set vs_string to vs_string+ char(10)+"["+round_dec(E_SET,2)+","+round(H_SET)+"]".
    }
    if (true) { // debug
        set vs_string to vs_string+ char(10)+ WP_FOLLOW_MODE_STRS[WP_FOLLOW_MODE].

        if USE_WP and (util_wp_queue_length() > 0) {
            local cur_wayp is util_wp_queue_first().
            if cur_wayp:length = 6 {
                set vs_string to vs_string+ char(10)+"a_have " + round_dec(arc_have[0],2) + "/" + round_dec(arc_have[1],2) + 
                                            char(10)+"h_have " + round_dec(head_have[0],2) + "/" + round_dec(head_have[1],2) + 
                                            char(10)+"n_have " + round_dec(new_have[0],2) + "/" + round_dec(new_have[1],2) + 
                                            char(10)+"c  " + round_dec(closeness,7) +
                                            char(10)+"outer " + outer_circle_flip.
            }
        }
    }
    return vs_string.
}
