
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

local TAIL_STRIKE is get_param(PARAM,"TAIL_STRIKE").
local VSET_MAX is get_param(PARAM,"VSET_MAX").
local GEAR_HEIGHT is get_param(PARAM,"GEAR_HEIGHT").

local GCAS_MARGIN is get_param(PARAM,"GCAS_MARGIN").
local GCAS_GAIN_MULTIPLIER is get_param(PARAM,"GCAS_GAIN_MULTIPLIER").

local GOT_USE_UTIL_WP is false.
local USE_UTIL_WP is false.

local lock AG to AG3.

local lock cur_vel_head to heading(vel_bear, vel_pitch).

local lock W_PITCH_NOM to RAD2DEG*(g0*ROT_GNOM_VERT)/max(50,vel).
local lock W_YAW_NOM to RAD2DEG*(g0*ROT_GNOM_LAT)/max(50,vel).

local VSET_MAN is FALSE.
local H_CLOSE is false.
local MIN_NAV_SRF_VEL is 0.01.

local vec_scale is 1.0.
local vec_width is 5.0.


// this function takes the desired NAV direction and finds
// an angular velocity to supply to the flcs. 
//  mostly it's just omega = K(NAV_DIR - prograde) + omega_ff 
function ap_nav_do_aero_rot {
    parameter vel_vec.
    parameter acc_vec.
    parameter head_dir.

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

    local w_g is vcrs(vel_prograde:vector, ship:up:vector)*
                (get_frame_accel_orbit()/max(1,vel)*RAD2DEG):mag.

    // local wff is -AP_NAV_W_H_SET*cur_vel_head:topvector + AP_NAV_W_E_SET*cur_vel_head:starvector.
    local wff is -vcrs(vel_vec,acc_vec):normalized*(acc_vec:mag/max(0.0001,vel_vec:mag))*RAD2DEG.

    local cur_pro is (-ship:facing)*vel_prograde.
    local target_pro is (-ship:facing)*vel_vec:direction.

    local ship_frame_error is 
        V(-wrap_angle(target_pro:pitch-cur_pro:pitch),
        wrap_angle(target_pro:yaw-cur_pro:yaw),
        0 ).

    local WGM is 1.0/kuniverse:timewarp:rate*(choose GCAS_GAIN_MULTIPLIER if GCAS_ACTIVE else 1.0).

    // omega applied by us
    local w_us is wff + WGM*K_PITCH*ship_frame_error:x*ship:facing:starvector +
                            -WGM*K_YAW*ship_frame_error:y*ship:facing:topvector.
    
    // omega applied by us including gravity for deciding roll
    local w_us_w_g is w_us-w_g.
    
    // util_hud_push_right("nav_w", "w_ff: (p,y): " + round_dec(wff*ship:facing:starvector,2) + "," + round_dec(-wff*ship:facing:topvector,2) +
    //     char(10)+ "w_g: (p,y): " + round_dec(w_g*ship:facing:starvector,2) + "," + round_dec(-w_g*ship:facing:topvector,2) +
    //     char(10)+ "w_us: (p,y): " + round_dec(w_us*ship:facing:starvector,2) + "," + round_dec(-w_us*ship:facing:topvector,2)).
    
    local have_roll_pre is haversine(0,0,w_us_w_g*ship:facing:starvector, -w_us_w_g*ship:facing:topvector).
    local roll_w is sat(have_roll_pre[1]/2.5,1.0).

    if ship:status = "LANDED" {
        set roll_w to 0.
    }

    local p_rot is w_us*ship:facing:starvector.
    local y_rot is -w_us*ship:facing:topvector.
    local r_rot is K_ROLL*convex(0-roll, wrap_angle(have_roll_pre[0]), roll_w).

    // util_hud_push_right("nav_w", ""+ round_dec(w_us*ship:facing:starvector,3) +
    //                             char(10)+round_dec(-w_us*ship:facing:topvector,3) +
    //                             char(10)+round_dec(w_us*ship:facing:forevector,3) +
    //                             char(10)+"rt:"+round_dec(have_roll_pre[0],1)).



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
                set AP_NAV_VEL to VSET_MAX*heading(vel_bear,escape_pitch):vector.
                set AP_NAV_ACC to V(0,0,0).
                set AP_NAV_ATT to ship:facing.


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



// handles a surface type waypoint
function ap_nav_srf_wp_guide {
    parameter wp.

    local final_radius is 100.
    if wp:haskey("nomg") {
        set final_radius to max(MIN_SRF_RAD, (wp["vel"])^2/(wp["nomg"]*g0)).
    } else {
        set final_radius to max(MIN_SRF_RAD, (wp["vel"])^2/(ROT_GNOM_VERT*g0)).
    }

    local align_data is list().
    if wp:haskey("lat") {
        local wp_vec is
            latlng(wp["lat"],wp["lng"]):altitudeposition(wp["alt"]+
            (choose GEAR_HEIGHT if GEAR else 0)).
        set AP_NAV_TIME_TO_WP to
            (ship:body:radius+ship:altitude)*DEG2RAD*
            haversine(ship:geoposition:lat,ship:geoposition:lng, wp["lat"],wp["lng"])[1]
            /max(1,vel).
        
        if wp:haskey("elev") and (wp_vec:mag < 9*final_radius) { 
            // do final alignment
            ap_nav_check_done(wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
            set align_data to ap_nav_align(wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
        } else {
            // do q_follow for height and wp heading
            ap_nav_check_done(wp_vec, ship:facing, ship:velocity:surface, final_radius).
            set align_data to ap_nav_q_target(wp["alt"],wp["vel"],latlng(wp["lat"],wp["lng"]):heading).
        }
    } else {
        // do q_follow for height and current heading
        set align_data to ap_nav_q_target(wp["alt"],wp["vel"],vel_bear).
        set AP_NAV_TIME_TO_WP to 9999.
    }
    return list(max(MIN_NAV_SRF_VEL,wp["vel"])*align_data[0], align_data[1], ship:facing).
}

function ap_nav_srf_stick {
    parameter u0. // throttle input
    parameter u1. // pitch input
    parameter u2. // yaw input
    parameter u3. // roll input

    local increment is 0.0.

    if AP_MODE_PILOT {
        set AP_NAV_VEL to ship:velocity:surface.
    } else if AP_MODE_VEL {
        set AP_NAV_VEL to ship:velocity:surface.
        set VSET_MAN to TRUE.
    } else if AP_MODE_NAV {
        set increment to 2.0*deadzone(u1,0.25).
        if increment <> 0 {
            set AP_NAV_VEL to ANGLEAXIS(-increment,ship:facing:starvector)*AP_NAV_VEL.
        }
        set increment to 2.0*deadzone(u3,0.25).
        if increment <> 0 {
            set AP_NAV_VEL to ANGLEAXIS(increment,ship:facing:topvector)*AP_NAV_VEL.
            // if increment > 0 and wrap_angle(AP_NAV_H_SET - vel_bear) > 175 {
            // } else if increment < 0 and wrap_angle(AP_NAV_H_SET - vel_bear) < -175 {
            // } else {
            //     set AP_NAV_H_SET To wrap_angle(AP_NAV_H_SET + increment).
            // }
        }
        set VSET_MAN to TRUE.
    }
    if VSET_MAN AND is_active_vessel() {
        set increment to 2.7*deadzone(2*u0-1,0.1).
        if increment <> 0 {
            set AP_NAV_VEL To MIN(MAX(AP_NAV_VEL:mag+increment,MIN_NAV_SRF_VEL),VSET_MAX)*AP_NAV_VEL:normalized.
        }
        set V_SET_DELTA to increment.
    }
}

local V_SET_DELTA is 0.
function ap_nav_srf_status_string {
    local dstr is "".

    local py_temp is pitch_yaw_from_dir(AP_NAV_VEL:direction).
    local AP_NAV_E_SET is py_temp[0].
    local AP_NAV_H_SET is py_temp[1].
    local AP_NAV_V_SET is AP_NAV_VEL:mag.

    if not GOT_USE_UTIL_WP {
        set USE_UTIL_WP to (defined UTIL_WP_ENABLED).
        set GOT_USE_UTIL_WP to true.
    }

    if AP_MODE_NAV or AP_MODE_VEL or (USE_UTIL_WP and (util_wp_queue_length() > 0)) {
        set dstr to "/"+round_dec(AP_NAV_V_SET,0).
        if (V_SET_DELTA > 0){
            set dstr to dstr + "+".
        } else if (V_SET_DELTA < 0){
            set dstr to dstr + "-".
        }
        set V_SET_DELTA to 0.
        set dstr to dstr+char(10)+"("+round_dec(AP_NAV_E_SET,2)+","+round(AP_NAV_H_SET)+")".
    }
    if (false) { // debug
        set dstr to dstr+ char(10)+ "NAV_K " + round_dec(K_PITCH,5) + 
                                  char(10)+    "     " + round_dec(K_YAW,5) + 
                                  char(10)+    "     " + round_dec(K_ROLL,5) + 
                                  char(10)+    "     " + round_dec(K_Q,5).
    }

    return dstr.
}
