
GLOBAL AP_NAV_SRF_ENABLED IS TRUE.
local PARAM is get_param(readJson("param.json"), "AP_NAV_SRF", lexicon()).

local K_Q is get_param(PARAM,"K_Q").
local K_E is get_param(PARAM,"K_E").

local FOLLOW_MODE_F is false.
local FOLLOW_MODE_A is false.
local FOLLOW_MODE_Q is false.

// NAV SRF START

// glimits
local ROT_GNOM_VERT is get_param(PARAM,"ROT_GNOM_VERT",1.5).
local ROT_GNOM_LAT is get_param(PARAM,"ROT_GNOM_LAT",0.1).
local ROT_GNOM_LONG is get_param(PARAM,"ROT_GNOM_LONG",1.0).
local MIN_SRF_RAD is get_param(PARAM,"MIN_SRF_RAD",250).

local VSET_MAX is get_param(PARAM,"VSET_MAX", 1250).
local GEAR_HEIGHT is get_param(PARAM,"GEAR_HEIGHT").


local function ap_nav_srf_check_done {
    parameter final_speed. // final speed upon approach
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
            return true.
        }
    }
    return false.
}

// returns a unit vector for velocity direction
// returns a vector for angular velocity in degrees per second
// both in ship raw frame
local on_circ_feedforward is false.
local function nav_align {
    parameter final_speed. // final speed upon approach
    parameter vec_final. // position vector to target
    parameter head_final. // desired heading upon approach
    parameter frame_vel. // a velocity vector in this frame
    parameter radius. // a turning radius.

    set FOLLOW_MODE_A to true.
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
        set FOLLOW_MODE_F to true.
        set alpha_x to head_have[1].
    } else {
        set FOLLOW_MODE_F to false.
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

    local acc_mag is choose frame_vel:mag^2/radius if FOLLOW_MODE_F else 0.
    
    set AP_NAV_TIME_TO_WP to vec_final:mag/max(1,frame_vel:mag).


    if false {
        local new_have_list is haversine_vec(head_final,new_arc_vector).

        set nav_align_debug_vec0 to VECDRAW(vec_final, 10*head_final:vector, RGB(1,1,1),
                "", 1.0, true, 0.25, true ).
        set nav_align_debug_vec1 to VECDRAW(vec_final, 10*head_final:starvector, RGB(0,0,1),
                "", 1.0, true, 0.25, true ).
        set nav_align_debug_vec2 to VECDRAW(vec_final, center_vec, RGB(0,1,0),
                "", 1.0, true, 0.25, true ).
        set nav_align_debug_vec3 to VECDRAW(V(0,0,0), 10*new_arc_vector, RGB(1,1,0),
                "", 1.0, true, 0.25, true ).
        set nav_align_debug_vec4 to VECDRAW(V(0,0,0), vec_final, RGB(0,1,0),
                "", 1.0, true, 0.25, true ).
        
        util_hud_push_right("nav_align", "e:"+round_fig(head_have[0],1) + 
            char(10) + "t:"+round_fig(head_have[1],1) +
            char(10) + "ne:"+round_fig(new_have_list[0],1) + 
            char(10) + "nt:"+round_fig(new_have_list[1],1) +
            char(10) + "ax:"+round_fig(alpha_x,1)).
    }

    return list(final_speed*new_arc_vector, acc_mag*centripetal_vector).
}

local function nav_q_target {
    parameter final_speed. // final speed upon approach
    parameter target_altitude.
    parameter target_heading.
    parameter target_distance is 99999999999. // assume target is far away
    parameter radius is 0. // a turning radius.

    set FOLLOW_MODE_Q to true.

    local qtar is simple_q(target_altitude,final_speed).
    local q_simp is simple_q(ship:altitude,ship:airspeed).

    local e_zero is simple_E(0,0).
    local etar is (simple_E(target_altitude,final_speed)-e_zero)/1000.
    local e_simp is (simple_E(ship:altitude,ship:airspeed)-e_zero)/1000.
    
    set AP_NAV_TIME_TO_WP to target_distance/max(1,ship:airspeed).
    
    local Fv is K_E*(etar-e_simp)/(ship:airspeed/400).
    local current_drag is get_pre_aero_acc()*ship_vel_dir:vector.
    set Fv to max(Fv, current_drag).
    if defined AP_AERO_ENGINES_ENABLED {
        local max_thrust is ap_aero_engines_get_max_thrust()/ship:mass.
        if max_thrust > 0.001 {
            set Fv to min(Fv, max_thrust + current_drag).
        } else {
            // we don't have engine power, only force we apply is drag
            set Fv to current_drag.
        }
    }
    
    local sin_elev is ( 2*Fv - K_Q*(qtar-q_simp)*(ship:airspeed/q_simp) )/(2*g0+ship:airspeed^2/5000).
    local elev is arcsin( sat( sin_elev, 0.5 )). // restrict climb/descent to +-30 degrees
    if false {
        util_hud_push_left("nav_q_target",
            "qt/"+ char(916)+" " + round_dec(qtar,3) + "/" + round_dec(qtar-q_simp,5) + char(10) + 
            "Et/Fv " + round_dec(etar,2) + "/" + round_dec(Fv,4) + char(10)).
    }

    local elev_diff is deadzone(arctan2(target_altitude-ship:altitude, target_distance+radius),abs(elev)).
    set elev_diff to arctan2(2*tan(elev_diff),1).
    local new_vel_vector is heading(target_heading,elev):vector.
    return list(ship:airspeed*new_vel_vector, (Fv - g0*sin_elev)*new_vel_vector).
}

// handles a surface type waypoint
// returns true if the waypoint has been reached
function ap_nav_srf_wp_guide {
    parameter wp.

    local wp_done is false.

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

        local geo_distance is (ship:body:radius+ship:altitude)*DEG2RAD*
            haversine(ship:geoposition:lat,ship:geoposition:lng, wp["lat"],wp["lng"])[1].
        
        if wp:haskey("elev") and (wp_vec:mag < 9*final_radius) { 
            // do final alignment
            set wp_done to ap_nav_srf_check_done(wp["vel"], wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
            set align_data to nav_align(wp["vel"],wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
        } else {
            // do q_follow for height and wp heading
            set wp_done to ap_nav_srf_check_done(ship:airspeed, wp_vec, ship:facing, ship:velocity:surface, final_radius).
            set align_data to nav_q_target(wp["vel"],wp["alt"],latlng(wp["lat"],wp["lng"]):heading, geo_distance, final_radius).
        }
    } else {
        // do q_follow for height and current heading
        set align_data to nav_q_target(wp["vel"],wp["alt"],vel_bear).
        set align_data[0] to align_data[0].
    }
    set AP_NAV_VEL to align_data[0].
    set AP_NAV_ACC to align_data[1] +
            (-(vectorexclude(ship:up:vector,ship:velocity:orbit):mag^2)*ship:up:forevector +
            + 2*(ship:geoposition:velocity:orbit:mag)*vectorExclude(ship:up:vector,ship:velocity:orbit):normalized*(ship:velocity:orbit*ship:up:vector))/(ship:body:radius + ship:altitude).
    set AP_NAV_ATT to ship:facing.

    if (wp_done) {
        ap_nav_wp_done().
    }

    return true.
}

local SRF_V_SET_DELTA is 0.
local stick_heading is 90.
local stick_pitch is 0.
local stick_vel is ship:airspeed.
function ap_nav_srf_stick {
    parameter u0 is SHIP:CONTROL:PILOTMAINTHROTTLE. // throttle input
    parameter u1 is SHIP:CONTROL:PILOTPITCH. // pitch input
    parameter u2 is SHIP:CONTROL:PILOTYAW. // yaw input
    parameter u3 is SHIP:CONTROL:PILOTROLL. // roll input
    local vel_increment is 0.0.
    local elev_increment is 0.0.
    local heading_increment is 0.0.
    local VSET_MAN is false.

    if not (defined AP_MODE_ENABLED) {
        return false.
    }
    if AP_MODE_PILOT {
        set stick_heading to vel_bear.
        set stick_pitch to vel_pitch.
        return false.
    } else if AP_MODE_VEL {
        set stick_heading to vel_bear.
        set stick_pitch to vel_pitch.
        set VSET_MAN to true.
    } else if AP_MODE_NAV {
        set elev_increment to 2.0*deadzone(u1,0.25).
        set heading_increment to 2.0*deadzone(u3,0.25).
        if elev_increment <> 0 or heading_increment <> 0 {
            local py_temp is pitch_yaw_from_dir(AP_NAV_VEL:direction).
            set stick_pitch to round_dec(py_temp[0] + elev_increment,1).
            set stick_heading to round(py_temp[1] + heading_increment).
        }
        set VSET_MAN to true.
    }
    if VSET_MAN and ISACTIVEVESSEL {
        set vel_increment to 2.7*deadzone(2*u0-1,0.1).
        if vel_increment <> 0 {
            set stick_vel to min(max(stick_vel+vel_increment,0.501),VSET_MAX).
        }
        set SRF_V_SET_DELTA to vel_increment.
    }
    local new_vel is round(stick_vel)*heading(stick_heading, stick_pitch):vector.
    if abs(new_vel:mag-AP_NAV_VEL:mag) > 2.7 {
        set stick_vel to AP_NAV_VEL:mag.
    } else {
        set AP_NAV_VEL to new_vel.
        set AP_NAV_ACC to V(0,0,0) +
            (-(vectorexclude(ship:up:vector,ship:velocity:orbit):mag^2)*ship:up:forevector +
            + 2*(ship:geoposition:velocity:orbit:mag)*vectorExclude(ship:up:vector,ship:velocity:orbit):normalized*(ship:velocity:orbit*ship:up:vector))/(ship:body:radius + ship:altitude).
        set AP_NAV_ATT to ship:facing.

    }
    if vectorangle(new_vel,AP_NAV_VEL) > 4 {
        local py_temp is pitch_yaw_from_dir(AP_NAV_VEL:direction).
        set stick_pitch to py_temp[0].
        set stick_heading to py_temp[1].
    }
    
    return true.
}

function ap_nav_srf_status_string {
    local dstr is "".
    local mode_str is "".
    local vel_mag is ap_nav_get_hud_vel():mag.

    local py_temp is pitch_yaw_from_dir(AP_NAV_VEL:direction).
    local AP_NAV_E_SET is py_temp[0].
    local AP_NAV_H_SET is py_temp[1].

    if FOLLOW_MODE_Q {
        set dstr to "/" + char(916) + round_dec(AP_NAV_ACC*AP_NAV_VEL:normalized,1).
    } else {
        set dstr to "/"+round_dec(vel_mag,0).
    }.
    if (SRF_V_SET_DELTA > 0){
        set dstr to dstr + "+".
    } else if (SRF_V_SET_DELTA < 0){
        set dstr to dstr + "-".
    }
    set SRF_V_SET_DELTA to 0.
    set dstr to dstr+char(10)+"("+round_dec(AP_NAV_E_SET,2)+","+round(AP_NAV_H_SET)+")".
    set DISPLAY_SRF to false.
    set mode_str to mode_str + "s".

    
    set mode_str to mode_str + 
    (choose "F" if FOLLOW_MODE_F else "") +
    (choose "A" if FOLLOW_MODE_A else "") +
    (choose "Q" if FOLLOW_MODE_Q else "").
    set FOLLOW_MODE_F to false.
    set FOLLOW_MODE_A to false.
    set FOLLOW_MODE_Q to false.
    
    set dstr to dstr + (choose "" if mode_str = "" else char(10)+mode_str).
    return dstr.
}