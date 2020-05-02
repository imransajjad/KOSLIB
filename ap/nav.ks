
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

// glimits
local ROT_GNOM_VERT is get_param(PARAM,"ROT_GNOM_VERT").
local ROT_GNOM_LAT is get_param(PARAM,"ROT_GNOM_LAT").
local ROT_GNOM_LONG is get_param(PARAM,"ROT_GNOM_LONG").

local K_PITCH is get_param(PARAM,"K_PITCH").
local K_YAW is get_param(PARAM,"K_YAW").
local K_ROLL is get_param(PARAM,"K_ROLL").
local K_HEADING is get_param(PARAM,"K_HEADING").
local HAVE_CLOSE is get_param(PARAM,"HAVE_CLOSE").
local ROLL_W_MIN is get_param(PARAM,"ROLL_W_MIN").
local ROLL_W_MAX is get_param(PARAM,"ROLL_W_MAX").
local GEAR_BANK_MAX is get_param(PARAM,"GEAR_BANK_MAX").
local BANK_MAX is get_param(PARAM,"BANK_MAX").
local TAIL_STRIKE is get_param(PARAM,"TAIL_STRIKE").
local VSET_MAX is get_param(PARAM,"VSET_MAX").
local GEAR_HEIGHT is get_param(PARAM,"GEAR_HEIGHT").


local GCAS_ENABLED is get_param(PARAM,"GCAS_ENABLED").
local GCAS_MARGIN is get_param(PARAM,"GCAS_MARGIN").
local GCAS_GAIN_MULTIPLIER is get_param(PARAM,"GCAS_GAIN_MULTIPLIER").

local PARAM is readJson("1:/param.json")["AP_FLCS_ROT"].
local MIN_SRF_RAD is get_param(PARAM,"CORNER_VELOCITY")^2/(g0*get_param(PARAM,"GLIM_VERT")).


// required global, will not modify
// roll, pitch, yaw
// vel
// vel_pitch, vel_bear
// pilot_input_u0, pilot_input_u1, pilot_input_u2, pilot_input_u3

local lock AG to AG3.

local lock cur_vel_head to heading(vel_bear, vel_pitch).

local USE_WP is (defined UTIL_WP_ENABLED) and UTIL_WP_ENABLED.
local USE_GCAS is (defined GCAS_ENABLED) and GCAS_ENABLED.
local GEAR_HEIGHT is (choose GEAR_HEIGHT if defined GEAR_HEIGHT else 0).

local AP_NAV_VERT_G is 0.1.
local AP_NAV_HOR_G is 1.0.

local lock W_PITCH_NOM to max(50,vel)/(g0*ROT_GNOM_VERT).
local lock W_YAW_NOM to max(50,vel)/(g0*ROT_GNOM_LAT).

local VSET_MAN is FALSE.

local V_SET_PREV is -1.0.
local V_SET is -1.0.
local E_SET is 0.0.
local R_SET is 0.0.
local H_SET is 90.0.

local H_CLOSE is false.
local WP_FOLLOW_MODE is 0.
local WP_FOLLOW_MODE_STRS is list("NAV_ARC","NAV_HEAD", "NAV_Q", "NAV_HOLD").

local W_E_SET is 0.0.
local W_H_SET is 0.0.

if vel > 1.0 {
    set V_SET_PREV to vel.
    set V_SET to vel.
    set E_SET to vel_pitch.
    set H_SET to vel_bear.
    set R_SET to 0.0.
}

local real_geodistance is 0.0.

local vec_scale is 1.0.
local vec_width is 2.0.

local debug_vectors is false.

if (debug_vectors) { // debug
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

function get_frame_accel {
    // if the negative of this value is applied to ship
    // it will always move in a straight line in sidereal frame

    return cur_vel_head:topvector*(-1.0*g0).
}

function ap_nav_do_flcs_rot {

    local wg is get_frame_accel()/max(1,vel)*RAD2DEG*cos(vel_pitch).

    local head_error is wrap_angle_until(H_SET - vel_bear).
    local elev_error is wrap_angle_until(E_SET - vel_pitch).

    local cur_pro is (-ship:facing)*heading(vel_bear, vel_pitch, roll).
    local target_pro is (-ship:facing)*heading(H_SET, E_SET, R_SET).

    local R_wv to (-ship:facing)*
        heading(H_SET, E_SET, R_SET).

    local ship_frame_error is 
        V(-wrap_angle_until(target_pro:pitch-cur_pro:pitch),
        wrap_angle_until(target_pro:yaw-cur_pro:yaw),
        wrap_angle_until(target_pro:roll-cur_pro:roll) ).
    local ship_frame_ff is
                // (choose 0.0 if AG3 else 1.0)*
                (R(0,0,-roll)*V(W_E_SET,W_H_SET,0)).

    local have_roll_pre is haversine(0,0,W_E_SET+elev_error-wg*cur_vel_head:topvector,
                                    W_H_SET+head_error-wg*cur_vel_head:starvector).

    // local have_roll is haversine(0,0,W_E_SET+world_frame_w:y-wg*ship:up:vector,
    //                                 W_H_SET+world_frame_w:x).
    local roll_w is 0*min(0,1-have_roll_pre[1]).

    local roll_target is sat( roll_w*(ship_frame_error:z + ship_frame_ff:z) 
                            +wrap_angle_until(have_roll_pre[0]) , 
                            (choose GEAR_BANK_MAX if GEAR else BANK_MAX)).
    
    if ship:status = "LANDED" {
        set roll_target to 0.
    }
    local r_rot is K_ROLL*wrap_angle_until(roll_target-roll).


    local p_rot is 0.0.
    local y_rot is 0.0.

    if USE_GCAS and GCAS_ACTIVE {
        set p_rot to GCAS_GAIN_MULTIPLIER*K_PITCH*ship_frame_error:x.
        set y_rot to GCAS_GAIN_MULTIPLIER*K_YAW*ship_frame_error:y.
    } else {
        set p_rot to sat(K_PITCH*ship_frame_error:x + ship_frame_ff:x, 2.0*W_PITCH_NOM).
        set y_rot to sat(K_YAW*ship_frame_error:y + ship_frame_ff:y, 2.0*W_YAW_NOM).
    
    }
    // util_hud_push_right("ap_nav_rtar", "rtar "+round_dec(roll_target,1)).
    // util_hud_push_right("ap_nav_debug", "rtar "+round_dec(wg*ship:up:vector,2)).
    // util_hud_push_right("ap_nav_pyrot", ""+round_dec(p_rot,1)+","+round_dec(y_rot,1)+","+round_dec(r_rot,1) ).
    ap_flcs_rot(DEG2RAD*p_rot, DEG2RAD*y_rot, DEG2RAD*r_rot ,true).
}

// does maneuver nodes in spaceflight when they are encountered
function ap_nav_do_man {
    return.
}

local function gcas_vector_impact {
    parameter impact_vector.
    local sticky_factor is 2.0.

    local impact_distance is impact_vector*heading(vel_bear,0):vector.
    local impact_latlng is haversine_latlng(ship:geoposition:lat, ship:geoposition:lng,
            vel_bear ,RAD2DEG*impact_distance/ship:body:radius ).
    local impact_alt is max(latlng(impact_latlng[0],impact_latlng[1]):terrainheight,0).
    return (ship:altitude+impact_vector*ship:up:vector < 
        impact_alt+GCAS_MARGIN + (choose sticky_factor*GCAS_MARGIN if GCAS_ACTIVE else 0)).
}

local GCAS_ARMED is false.
local GCAS_ACTIVE is false.
local n_impact_pts is 5.
local straight_vector is V(0,0,0).
local impact_vector is V(0,0,0).
local old_mode_str is "".

function ap_nav_gcas {
    // ground collision avoidance system
    local escape_pitch is 10+max(0,vel_pitch).
    local react_time is 1.0.

    if not GEAR and not SAS {
        local rates is ap_flcs_rot_maxrates().
        set rates[0] to max(rates[0]/1.0,1.0).
        set rates[1] to max(rates[1],1.0).
        set rates[2] to max(rates[2]/6.0,1.0).

        local t_preroll is abs(roll/rates[2]) + react_time.
        local vel_pitch_up is min(90,max(0,-vel_pitch+escape_pitch)).
        local t_pitch is abs(vel_pitch_up/rates[0]).

        set straight_vector to
                ship:srfprograde:forevector*( (t_pitch + t_preroll)*vel ).
        set impact_vector to 
                ship:srfprograde:forevector*( vel/(DEG2RAD*rates[0])*sin(vel_pitch_up) + t_preroll*vel ) +
                ship:srfprograde:topvector*( vel/(DEG2RAD*rates[0])*(1-cos(vel_pitch_up))).

        if not GCAS_ARMED {
            if gcas_vector_impact(straight_vector) {
                util_hud_push_right("NAV_GCAS", "GCAS").
                print "GCAS armed".
                set GCAS_ARMED to true.
            }
        } else if GCAS_ARMED {
            local impact_condition is false.
            for i in range(0,n_impact_pts) {
                set impact_condition to impact_condition or gcas_vector_impact(((i+1)/n_impact_pts)*impact_vector).
            }

            if not GCAS_ACTIVE and impact_condition {
                // GCAS is active here, will put in NAV mode after setting headings etc
                set GCAS_ACTIVE to true.
                util_hud_push_right("NAV_GCAS", "GCAS"+char(10)+"ACTIVE").
                print "GCAS ACTIVE".
                set old_mode_str to ap_mode_get_str().
                ap_mode_set("NAV").

            } else if GCAS_ACTIVE and not impact_condition {
                ap_mode_set(old_mode_str).
                print "GCAS INACTIVE".
                util_hud_push_right("NAV_GCAS", "GCAS").
                set GCAS_ACTIVE to false.
            }

            if GCAS_ACTIVE {
                set E_SET to escape_pitch.
                set H_SET to vel_bear.
                set R_SET to 0.
                set W_E_SET to DEG2RAD*rates[0].
                set W_H_SET to 0.
                set V_SET to VSET_MAX.

                if (ship:altitude - GCAS_MARGIN < max(ship:geoposition:terrainheight,0))
                {
                    print "GCAS FLOOR BREACHED".
                    util_hud_push_right("NAV_GCAS", "GCAS"+char(10)+"BREACHED").
                }
            }

            if not GCAS_ACTIVE and not gcas_vector_impact(straight_vector) {
                util_hud_pop_right("NAV_GCAS").
                print "GCAS disarmed".
                set GCAS_ARMED to false.
            }
        }
    } else if GCAS_ARMED or GCAS_ACTIVE {
        // if GEAR or SAS, undo everything
        ap_mode_set(old_mode_str).
        util_hud_pop_right("NAV_GCAS").
        set GCAS_ARMED to false.
        set GCAS_ACTIVE to false.
    }
    return GCAS_ACTIVE.
}


local head_have is list(0,0,0).
local new_have is list(0,0,0).

local wp_vec is V(0,0,0).
local wp_final_head is R(0,0,0).
local final_radius is 100.
local farness is 1.0.
local alpha_x is 0.0.
local turn_on is false.

// handles a surface type waypoint
local function srf_wp_disp {
    parameter wp.

    set V_SET to wp["vel"].
    set R_SET to wp["roll"].
    set W_E_SET to 0.
    set W_H_SET to 0.

    // if waypoint has any form of destination
    if wp:haskey("lat") and wp:haskey("lng") and wp:haskey("alt") {

        set wp_vec to
            latlng(wp["lat"],wp["lng"]):
                altitudeposition(wp["alt"]+
                (choose GEAR_HEIGHT if GEAR else 0)).
        set wp_final_head to heading(wp["head"],wp["elev"]).

        set final_radius to max(MIN_SRF_RAD, wp["vel"]^2/(wp["nomg"]*g0)).
        set farness to wp_vec:mag/final_radius.

        if wp_vec:mag > 10000 and wp_vec:mag > 3*final_radius {
            set H_SET to latlng(wp["lat"],wp["lng"]):heading.
            set WP_FOLLOW_MODE to 2. // just get close enough
        } else {
            set WP_FOLLOW_MODE to 1. // head to arc start point
        }

        // if we are in terminal
        local arc_radius is (ship:body:radius+ship:altitude).
        set real_geodistance to
            arc_radius*DEG2RAD*haversine(ship:geoposition:lat,
                ship:geoposition:lng, wp["lat"],wp["lng"])[1].
        
        local time_dir is ship:srfprograde:vector*wp_vec:normalized.
        local time_to is wp_vec:mag/(vel).

        if (time_to < 3) {
            local angle_to is vectorangle(wp_vec,ship:velocity:surface).

            if ( angle_to > 30) or
                (angle_to > 12.5 and time_to < 2) or 
                ( time_to < 1) {
                // print "dist ("+ round_dec(wp_vec*heading(vel_bear,vel_pitch):vector,2)
                //         + "," + round_dec(wp_vec*heading(vel_bear,vel_pitch):starvector,2)
                //         + "," + round_dec(wp_vec*heading(vel_bear,vel_pitch):topvector,2)
                //         + ")".
                print "(" + round_dec(ship:altitude,0) + "," +
                            round_dec(vel,0) + "," +
                            round_dec(ship:geoposition:lat,1) + "," +
                            round_dec(ship:geoposition:lng,1) + "," +
                            round_dec(vel_pitch,1) + "," +
                            round_dec(vel_bear,1) + ")".
                PRINT "Reached Waypoint " + util_wp_queue_length().
                set alpha_x to 0.
                util_wp_done().
                set turn_on to false.
                if util_wp_queue_length() = 0 {
                    set E_SET to vel_pitch.
                    set H_SET to vel_bear.
                    set V_SET to vel.
                }
            }
        }

    } else if wp:haskey("roll") {
        set WP_FOLLOW_MODE to 3. // hold state
        set H_SET to vel_bear.
    }

    // climb/descend to target altitude
    if ((WP_FOLLOW_MODE = 3) or (WP_FOLLOW_MODE = 2)) and wp:haskey("alt") {

        local max_vangle is 30.

        local max_vturn is AP_NAV_VERT_G/vel.

        local linear_climb_boundary is (max(vel,1.0)^2)/(AP_NAV_VERT_G*g0)*(1-cos(max_vangle)).
        //set local_climb_boundary to 0.1*level_radius.
        //set local_gain to arccos(1-abs(local_climb_boundary)/level_radius)/local_climb_boundary.
        local hdiff is wp["alt"] - ship:ALTITUDE.

        if abs(hdiff) < linear_climb_boundary {
            set H_CLOSE to true.
            set W_E_SET to -(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
            set E_SET to RAD2DEG*sqrt(abs(hdiff)*AP_NAV_VERT_G*g0)/(max(vel,1.0))*sat(hdiff,1.0).
        } else {
            set H_CLOSE to false.
            set W_E_SET to +(AP_NAV_VERT_G*g0)/max(vel,1.0)*sat(hdiff,1.0).
            set E_SET to 0.95*pitch.
            if (pitch > max_vangle and W_E_SET > 0) or
                (pitch < -max_vangle and W_E_SET < 0){
                    set W_E_SET to 0.
                    set E_SET to sat(pitch,max_vangle).
            }
        }
    }

    // set everything if waypoint has target orientation
    if (WP_FOLLOW_MODE = 1) or (WP_FOLLOW_MODE = 0) {
        // extract altitude, velocity, lat, long, final_pitch, final_heading
        // set V_SET to convex(V_SET_PREV,wp["vel"],min(1,max(0,3-farness))).
        set V_SET to wp["vel"].

        set head_have to haversine_dir((-wp_final_head)*wp_vec:direction).

        if (0.99999*farness <= 2*sin(head_have[1]) ) {
            set WP_FOLLOW_MODE to 0.
        }
        if (WP_FOLLOW_MODE = 1) {
            set alpha_x to arcsin(((farness-sin(head_have[1])) - farness*cos(head_have[1])*sqrt(1-2/farness*sin(head_have[1])))
                  / ( farness^2 -2*farness*sin(head_have[1]) + 1)).
            // set alpha_x to alpha_x - 
            //     (1-cos(head_have[1]+alpha_x)-farness*sin(alpha_x))/
            //     (2*(sin(head_have[1]+alpha_x)-farness*cos(alpha_x))).
            // set alpha_x to 2/farness*sin(head_have[1]/2)*sin(head_have[1]).
        } else if (WP_FOLLOW_MODE = 0) {
            set alpha_x to head_have[1].

        }



        set new_have to list(head_have[0],head_have[1]+alpha_x, head_have[2]).
        set c_have to list(head_have[0],head_have[1]+alpha_x-90, head_have[2]).

        local new_arc_direction is wp_final_head*dir_haversine(new_have).
        local centripetal_vector is wp_final_head*dir_haversine(c_have):vector.

        if (debug_vectors) { // debug
            local bear_to_final is rotateFromTo(wp_vec,wp_final_head:vector).
            set nav_debug_vec0:vec to wp_vec.
            set nav_debug_vec1:vec to final_radius*centripetal_vector. // arc
            set nav_debug_vec2:vec to wp_vec.
            set nav_debug_vec3:vec to 100*new_arc_direction:vector. // res

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

        if (WP_FOLLOW_MODE = 0) {
            local cur_vel_head_set is heading(H_SET, E_SET).
            local w_mag is max(vel,7)/final_radius*RAD2DEG.
            set W_E_SET to centripetal_vector*cur_vel_head:topvector*w_mag.
            set W_H_SET to centripetal_vector*cur_vel_head:starvector*w_mag.
        }
    }
}


function ap_nav_disp {
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

    if (USE_GCAS) and ap_nav_gcas(){
        return.
    }

    local increment is 0.0.
    set VSET_MAN to false.

    set V_SET_PREV to V_SET.

    if USE_WP and (util_wp_queue_length() > 0) {
        local cur_wayp is util_wp_queue_first().
        if cur_wayp["mode"] = "srf" {
            srf_wp_disp(cur_wayp).
        }
    } else {
        set W_E_SET to 0.0.
        set W_H_SET to 0.0.
        if AP_FLCS_CHECK() {
            set E_SET to vel_pitch.
            set H_SET to vel_bear.
            set V_SET to vel.
        } else if AP_VEL_CHECK() {
            set E_SET to vel_pitch.
            set H_SET to vel_bear.
            set VSET_MAN to TRUE.
        } else if AP_NAV_CHECK() {
            set increment to 2.0*deadzone(pilot_input_u1,0.25).
            if increment <> 0 {
                set E_SET To sat(E_SET + increment, 90).
            }
            set HSET_MAN to TRUE.
            set increment to 4.0*deadzone(pilot_input_u3,0.25).
            if increment <> 0 {
                set H_SET To wrap_angle_until(H_SET + increment).
            }
            set VSET_MAN to TRUE.
        }
        set real_geodistance to 0.0.
    }

    if VSET_MAN AND is_active_vessel() {
        set increment to 2.7*deadzone(2*pilot_input_u0-1,0.1).
        if increment <> 0 {
            set V_SET To MIN(MAX(V_SET+increment,-1),VSET_MAX).
            //vec_info_draw().
        }
    }
    if ship:status = "LANDED" {
        set E_SET to max(-1,min(E_SET, TAIL_STRIKE)).
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
    if (false) { // debug
        set vs_string to vs_string+ char(10)+ WP_FOLLOW_MODE_STRS[WP_FOLLOW_MODE].
        set vs_string to vs_string+ char(10)+"["+round_dec(wrap_angle_until(E_SET - vel_pitch),2)+","+round_dec(wrap_angle_until(H_SET - vel_bear),2)+"]".
        set vs_string to vs_string+ char(10)+"["+round_dec(W_E_SET,5)+","+round_dec(W_H_SET,5)+"]".

        set vs_string to vs_string+ char(10)+ "NAV_K " + round_dec(K_PITCH,5) + 
                                  char(10)+    "  " + round_dec(K_YAW,5) + 
                                  char(10)+    "  " + round_dec(K_ROLL,5) + 
                                  char(10)+    "  " + round_dec(K_HEADING,5).

        if USE_WP and (util_wp_queue_length() > 0) {
            set vs_string to vs_string+ char(10)+"h_have " + round_dec(head_have[0],2) + "/" + round_dec(head_have[1],2) +
                                        char(10)+"n_have " + round_dec(new_have[0],2) + "/" + round_dec(new_have[1],2) +
                                        char(10)+"/\  " + round_dec(farness,7) +
                                        char(10)+"O" + round_dec(final_radius,7).
        }
    }
    return vs_string.
}
