
GLOBAL AP_NAV_SRF_ENABLED IS TRUE.
local PARAM is readJson("1:/param.json")["AP_NAV"].

// glimits
local ROT_GNOM_VERT is get_param(PARAM,"ROT_GNOM_VERT",1.5).
local ROT_GNOM_LAT is get_param(PARAM,"ROT_GNOM_LAT",0.1).
local ROT_GNOM_LONG is get_param(PARAM,"ROT_GNOM_LONG",1.0).
local MIN_SRF_RAD is get_param(PARAM,"MIN_SRF_RAD",250).

local K_PITCH is get_param(PARAM,"K_PITCH").
local K_YAW is get_param(PARAM,"K_YAW").
local K_ROLL is get_param(PARAM,"K_ROLL").
local K_Q is get_param(PARAM,"K_Q").

local TAIL_STRIKE is get_param(PARAM,"TAIL_STRIKE").
local VSET_MAX is get_param(PARAM,"VSET_MAX").
local GEAR_HEIGHT is get_param(PARAM,"GEAR_HEIGHT").

local USE_GCAS is get_param(PARAM,"GCAS_ENABLED",false).
local GCAS_MARGIN is get_param(PARAM,"GCAS_MARGIN").
local GCAS_GAIN_MULTIPLIER is get_param(PARAM,"GCAS_GAIN_MULTIPLIER").

local USE_UTIL_WP is readJson("1:/param.json"):haskey("UTIL_WP").

local lock AG to AG3.

local lock cur_vel_head to heading(vel_bear, vel_pitch).

local lock W_PITCH_NOM to RAD2DEG*(g0*ROT_GNOM_VERT)/max(50,vel).
local lock W_YAW_NOM to RAD2DEG*(g0*ROT_GNOM_LAT)/max(50,vel).

local VSET_MAN is FALSE.
local H_CLOSE is false.
local WP_FOLLOW_MODE is lexicon("F", false, "A", false, "Q", false).

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

// this function takes the desired NAV direction and finds
// an angular velocity to supply to the flcs. 
//  mostly it's just omega = K(NAV_DIR - prograde) + omega_ff 
function ap_nav_do_aero_rot {
    
    // a roll command is found as follows:
    // pitch errors and yaw errors are found in the ship frame
    // the omega required to overcome gravity pitching down plus 
    // the feed forward rates are also expressed in the ship frame.
    // we now have a omega that we have to "apply", but without any roll
    // 
    // this omega is fed to the haversine and we get a bearing and magnitude
    // like information about the pitch and yaw components of omega. Then
    // omega_roll = -K*have_roll_pre[0]
    // uses roll to minimze the bearing in the ship frame so that most omega is
    // applied by pitch and not by yaw

    local wg is vcrs(vel_prograde:vector, ship:up:vector)*
                (get_frame_accel_orbit()/max(1,vel)*RAD2DEG):mag.

    local wff is -AP_NAV_W_H_SET*cur_vel_head:topvector + AP_NAV_W_E_SET*cur_vel_head:starvector.

    local cur_pro is (-ship:facing)*heading(vel_bear, vel_pitch, roll).
    local target_pro is (-ship:facing)*heading(AP_NAV_H_SET, AP_NAV_E_SET, AP_NAV_R_SET).

    local ship_frame_error is 
        V(-wrap_angle_until(target_pro:pitch-cur_pro:pitch),
        wrap_angle_until(target_pro:yaw-cur_pro:yaw),
        wrap_angle_until(target_pro:roll-cur_pro:roll) ).
    local ship_frame_ff is (R(0,0,-roll)*V(AP_NAV_W_E_SET,AP_NAV_W_H_SET,0)).
    
    // omega applied by us
    local w_us is -wg+wff + K_PITCH*ship_frame_error:x*ship:facing:starvector +
                            -K_YAW*ship_frame_error:y*ship:facing:topvector.
    
    local have_roll_pre is haversine(0,0,w_us*ship:facing:starvector, -w_us*ship:facing:topvector).
    local roll_w is sat(have_roll_pre[1]/2.5,1.0).
    local roll_target is 0*(ship_frame_error:z + ship_frame_ff:z). // still need to test

    if ship:status = "LANDED" {
        set roll_target to 0.
        set roll_w to 0.
    }
    local r_rot is K_ROLL*convex(roll_target-roll, wrap_angle(have_roll_pre[0]), roll_w).

    // util_hud_push_right("nav_w", ""+ round_dec(w_us*ship:facing:starvector,3) +
    //                             char(10)+round_dec(-w_us*ship:facing:topvector,3) +
    //                             char(10)+round_dec(w_us*ship:facing:forevector,3) +
    //                             char(10)+"rt:"+round_dec(have_roll_pre[0],1)).

    local WGM is 1.0/kuniverse:timewarp:rate.

    local p_rot is 0.0.
    local y_rot is 0.0.

    if GCAS_ACTIVE {
        set p_rot to GCAS_GAIN_MULTIPLIER*K_PITCH*ship_frame_error:x.
        set y_rot to GCAS_GAIN_MULTIPLIER*K_YAW*ship_frame_error:y.
    } else {
        set p_rot to sat(WGM*K_PITCH*ship_frame_error:x + ship_frame_ff:x, 2.0*W_PITCH_NOM).
        set y_rot to sat(WGM*K_YAW*ship_frame_error:y + ship_frame_ff:y, 2.0*W_YAW_NOM).
    
    }
    ap_aero_rot_do(DEG2RAD*p_rot, DEG2RAD*y_rot, DEG2RAD*r_rot ,true).

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

function ap_nav_srf_gcas {
    // ground collision avoidance system
    local escape_pitch is 10+max(0,vel_pitch).
    local react_time is 1.0.

    if not GEAR and not SAS {
        local rates is ap_aero_rot_maxrates().
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
                set AP_NAV_E_SET to escape_pitch.
                set AP_NAV_H_SET to vel_bear.
                set AP_NAV_R_SET to 0.
                set AP_NAV_W_E_SET to DEG2RAD*rates[0].
                set AP_NAV_W_H_SET to 0.
                set AP_NAV_V_SET to VSET_MAX.

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
local in_circ is 0.0.
local alpha_x is 0.0.

// handles a surface type waypoint
function ap_nav_srf_wp_guide {
    parameter wp.

    if (USE_GCAS) and ap_nav_srf_gcas(){
        return.
    }

    set AP_NAV_V_SET to wp["vel"].
    set AP_NAV_R_SET to wp["roll"].
    set AP_NAV_W_E_SET to 0.
    set AP_NAV_W_H_SET to 0.

    // find time to waypoint // waypoint has to have destination
    set AP_NAV_TIME_TO_WP to
        (ship:body:radius+ship:altitude)*DEG2RAD*
        haversine(ship:geoposition:lat,ship:geoposition:lng, wp["lat"],wp["lng"])[1]
        /max(1,vel).

    set wp_vec to
        latlng(wp["lat"],wp["lng"]):altitudeposition(wp["alt"]+
            (choose GEAR_HEIGHT if GEAR else 0)).
    set wp_final_head to heading(wp["head"],wp["elev"]).

    set final_radius to max(MIN_SRF_RAD, wp["vel"]^2/(wp["nomg"]*g0)).
    set farness to wp_vec:mag/final_radius.

    if ( final_radius > 10000) or (wp_vec:mag > 9*final_radius) {
        set AP_NAV_H_SET to latlng(wp["lat"],wp["lng"]):heading.
        set WP_FOLLOW_MODE["F"] to false.
        set WP_FOLLOW_MODE["A"] to false.
        set WP_FOLLOW_MODE["Q"] to true. // just get close enough
    } else {
        set WP_FOLLOW_MODE["A"] to true. // head to arc start point
        set WP_FOLLOW_MODE["Q"] to false.
    }

    // if we are in terminal
    
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
            PRINT "Reached Waypoint " + (util_wp_queue_length()-1).
            set alpha_x to 0.
            util_wp_done().
            set WP_FOLLOW_MODE["F"] to false.
            if util_wp_queue_length() = 0 {
                set AP_NAV_E_SET to vel_pitch.
                set AP_NAV_H_SET to vel_bear.
                set AP_NAV_V_SET to vel.
            }
            return.
        }
    }

    // climb/descend to target altitude
    if WP_FOLLOW_MODE["Q"] {

        local sin_max_vangle is 0.5. // sin(30).
        local qtar is simple_q(wp["alt"],wp["vel"]).
        local q_simp is simple_q(ship:altitude,ship:airspeed).

        // util_hud_push_right("simple_q_simp", ""+round_dec(q_simp,3)+"/"+round_dec(qtar,3)).

        set AP_NAV_E_SET to arcsin(sat(-K_Q*(qtar-q_simp), sin_max_vangle)).
        set AP_NAV_E_SET to max(AP_NAV_E_SET, -arcsin(min(1.0,ship:altitude/vel/5))).

    }

    // if close enough, do heading alignment circle
    if WP_FOLLOW_MODE["A"] {
        // extract altitude, velocity, lat, long, final_pitch, final_heading
        // set AP_NAV_V_SET to convex(AP_NAV_V_SET_PREV,wp["vel"],min(1,max(0,3-farness))).

        set head_have to haversine_dir((-wp_final_head)*wp_vec:direction).

        set in_circ to farness/max(0.00001,2*sin(head_have[1])).

        if (WP_FOLLOW_MODE["F"]) {
            set alpha_x to head_have[1].
        } else if (in_circ < 1.0) {
            // set alpha_x to head_have[1]*(2*sin(head_have[1])/farness)^2.
            set alpha_x to head_have[1].
            set WP_FOLLOW_MODE["F"] to true.
        } else {
            // set alpha_x to head_have[1]*(2*sin(head_have[1])/farness)^2.

            set alpha_x to arcsin(((farness-sin(head_have[1])) - farness*cos(head_have[1])*sqrt(1-2/farness*sin(head_have[1])))
                  / ( farness^2 -2*farness*sin(head_have[1]) + 1)).
            // set WP_FOLLOW_MODE["F"] to false.
            if (head_have[1] <= alpha_x){
                set alpha_x to head_have[1].
                set WP_FOLLOW_MODE["F"] to true.
            }
        }
        
        if WP_FOLLOW_MODE["F"] {

        } else {

            // set alpha_x to alpha_x - 
            //     (1-cos(head_have[1]+alpha_x)-farness*sin(alpha_x))/
            //     (2*(sin(head_have[1]+alpha_x)-farness*cos(alpha_x))).
            // set alpha_x to 2/farness*sin(head_have[1]/2)*sin(head_have[1]).
        }

        // set alpha_x to head_have[1].
        // if (in_circ > 1.0) {
        //     set alpha_x to arcsin(((farness-sin(head_have[1])) - farness*cos(head_have[1])*sqrt(1-2/farness*sin(head_have[1])))
        //           / ( farness^2 -2*farness*sin(head_have[1]) + 1)).
        // }
        // set alpha_x to min(head_have[1], alpha_x).

        // set alpha_x to head_have[1]*(2*sin(head_have[1])/farness)^2.



        set new_have to list(head_have[0],head_have[1]+alpha_x, head_have[2]).
        set c_have to list(head_have[0],head_have[1]+alpha_x-90, head_have[2]).

        local new_arc_direction is wp_final_head*dir_haversine(new_have).
        local centripetal_vector is wp_final_head*dir_haversine(c_have):vector.

        local py_temp is pitch_yaw_from_dir(new_arc_direction).
        set AP_NAV_E_SET to py_temp[0].
        set AP_NAV_H_SET to py_temp[1].
        set AP_NAV_R_SET to 0.

        set AP_NAV_E_SET to max(AP_NAV_E_SET, -arcsin(min(1.0,ship:altitude/vel/5))).

        if WP_FOLLOW_MODE["F"] and AG3{
            local cur_vel_head_set is heading(AP_NAV_H_SET, AP_NAV_E_SET).
            local w_mag is max(vel,7)/final_radius*RAD2DEG.
            set AP_NAV_W_E_SET to centripetal_vector*cur_vel_head:topvector*w_mag.
            set AP_NAV_W_H_SET to centripetal_vector*cur_vel_head:starvector*w_mag.
        }

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
    }
}

function ap_nav_srf_stick {

    if (USE_GCAS) and ap_nav_srf_gcas(){
        return.
    }

    local increment is 0.0.

    if AP_MODE_PILOT {
        set AP_NAV_E_SET to vel_pitch.
        set AP_NAV_H_SET to vel_bear.
        set AP_NAV_V_SET to vel.
    } else if AP_MODE_VEL {
        set AP_NAV_E_SET to vel_pitch.
        set AP_NAV_H_SET to vel_bear.
        set VSET_MAN to TRUE.
    } else if AP_MODE_NAV {
        set increment to 2.0*deadzone(pilot_input_u1,0.25).
        if increment <> 0 {
            set AP_NAV_E_SET To sat(AP_NAV_E_SET + increment, 90).
        }
        set HSET_MAN to TRUE.
        set increment to 4.0*deadzone(pilot_input_u3,0.25).
        if increment <> 0 {
            set AP_NAV_H_SET To wrap_angle_until(AP_NAV_H_SET + increment).
        }
        set VSET_MAN to TRUE.
    }
    if VSET_MAN AND is_active_vessel() {
        set increment to 2.7*deadzone(2*pilot_input_u0-1,0.1).
        if increment <> 0 {
            set AP_NAV_V_SET To MIN(MAX(AP_NAV_V_SET+increment,-1),VSET_MAX).
        }
    }
}

function ap_nav_srf_status_string {
    local dstr is "".
    if AP_MODE_NAV or AP_MODE_VEL or (USE_UTIL_WP and (util_wp_queue_length() > 0)) {
        set dstr to "/"+round_dec(AP_NAV_V_SET,0).
        if (AP_NAV_V_SET_PREV < AP_NAV_V_SET){
            set dstr to dstr + "+".
        } else if (AP_NAV_V_SET_PREV > AP_NAV_V_SET){
            set dstr to dstr + "-".
        }
        set dstr to dstr + char(10).
        for i in WP_FOLLOW_MODE:keys {
            if WP_FOLLOW_MODE[i] { set dstr to dstr+i.}
        }

        set dstr to dstr+"("+round_dec(AP_NAV_E_SET,2)+","+round(AP_NAV_H_SET)+")".
    }
    if (false) { // debug
        set dstr to dstr+ char(10)+"["+round_dec(wrap_angle_until(AP_NAV_E_SET - vel_pitch),2)+","+round_dec(wrap_angle_until(AP_NAV_H_SET - vel_bear),2)+"]".
        set dstr to dstr+ char(10)+"["+round_dec(AP_NAV_W_E_SET,5)+","+round_dec(AP_NAV_W_H_SET,5)+"]".

        set dstr to dstr+ char(10)+ "NAV_K " + round_dec(K_PITCH,5) + 
                                  char(10)+    "     " + round_dec(K_YAW,5) + 
                                  char(10)+    "     " + round_dec(K_ROLL,5) + 
                                  char(10)+    "     " + round_dec(K_Q,5).
        
        set dstr to dstr+ "h_have " + round_dec(head_have[0],2) +
                                                 "/" + round_dec(head_have[1],2) +
                char(10)+"n_have " + round_dec(new_have[0],2) +
                                                 "/" + round_dec(new_have[1],2) +
                char(10)+"/\  " + round_dec(farness,2) +
                char(10)+"/c  " + round_dec(in_circ,2) +
                char(10)+"O" + round_dec(final_radius,0) +
                (choose char(10)+"AG" if AG else "").
    }

    return dstr.
}
