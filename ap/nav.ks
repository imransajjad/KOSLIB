
GLOBAL AP_NAV_ENABLED IS TRUE.
local PARAM is get_param(readJson("param.json"), "AP_NAV", lexicon()).

local K_Q is get_param(PARAM,"K_Q").
local K_E is get_param(PARAM,"K_E").

// NAV GLOBALS (other files should read but not write to these)
global AP_NAV_TIME_TO_WP is 0.

global AP_NAV_VEL is V(0,0,0). // is surface if < 36000, else orbital
global AP_NAV_ACC is V(0,0,0).
global AP_NAV_ATT is R(0,0,0).

global AP_NAV_IN_SURFACE is false. // use this global !!!
global AP_NAV_IN_ORBIT is true.

local previous_body is "Kerbin".
local body_navchange_alt is get_param(BODY_navball_change_alt, ship:body:name, 36000).

local FOLLOW_MODE_F is false.
local FOLLOW_MODE_A is false.
local FOLLOW_MODE_Q is false.

local DISPLAY_SRF is false.
local DISPLAY_ORB is false.
local DISPLAY_TAR is false.

local DISPLAY_HUD_VEL is false.
local CLEAR_HUD_VEL is false.

// HELPER FUNCTIONS START

// returns the nav velocity of a vessel in "our" frame
local function get_vessel_vel {
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

local function nav_check_done {
    parameter final_speed. // final speed upon approach
    parameter vec_final. // position vector to target
    parameter head_final. // desired heading upon approach
    parameter frame_vel. // a velocity vector in this frame
    parameter radius. // a turning radius.

    local time_dir is frame_vel*vec_final:normalized.
    local time_to is vec_final:mag/max(frame_vel:mag,0.0001).

    if (time_to < 3) and (final_speed > MAX_STATION_KEEP_SPEED) {
        local angle_to is vectorangle(vec_final,frame_vel).

        if ( angle_to > 30) or
            (angle_to > 12.5 and time_to < 2) or 
            ( time_to < 1) {
            local wp_reached_str is  "reached waypoint " + (util_wp_queue_length()-1).
            print wp_reached_str.
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event(wp_reached_str).
            }
            util_wp_done().
            set AP_NAV_TIME_TO_WP to 0.
        }
    }
}

// HELPER FUNCTIONS END

// NAV SRF START

// glimits
local ROT_GNOM_VERT is get_param(PARAM,"ROT_GNOM_VERT",1.5).
local ROT_GNOM_LAT is get_param(PARAM,"ROT_GNOM_LAT",0.1).
local ROT_GNOM_LONG is get_param(PARAM,"ROT_GNOM_LONG",1.0).
local MIN_SRF_RAD is get_param(PARAM,"MIN_SRF_RAD",250).

local VSET_MAX is get_param(PARAM,"VSET_MAX").
local GEAR_HEIGHT is get_param(PARAM,"GEAR_HEIGHT").

local MIN_NAV_SRF_VEL is 0.01.


// handles a surface type waypoint
local function srf_wp_guide {
    parameter wp.

    if not (wp["mode"] = "srf") {
        return false.
    }

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
            nav_check_done(wp["vel"], wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
            set align_data to nav_align(wp["vel"],wp_vec, heading(wp["head"],wp["elev"]), ship:velocity:surface, final_radius).
        } else {
            // do q_follow for height and wp heading
            nav_check_done(ship:airspeed, wp_vec, ship:facing, ship:velocity:surface, final_radius).
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

    return true.
}

local SRF_V_SET_DELTA is 0.
local stick_heading is 90.
local stick_pitch is 0.
local stick_vel is ship:airspeed.
local function srf_stick {
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

// NAV SRF END

// NAV ORB START

local thrust_vector is V(0,0,1).
local thrust_string is "x".
// is a vector in the current ship:facing frame
// note that controlpart alters ship:facing frame

local function orb_stick {
    
    if defined AP_MODE_ENABLED and AP_MODE_NAV {
        local delta is ship:control:pilottranslation.
        if (delta):mag > 0.5 and (delta-thrust_vector):mag > 0.5 {
            set thrust_vector to delta:normalized.
            set thrust_string to "" + 
                (choose char(8592) if delta:x < -0.5 else "") +
                (choose char(8594) if delta:x > 0.5 else "") +
                (choose char(8595) if delta:y < -0.5 else "") +
                (choose char(8593) if delta:y > 0.5 else "") +
                (choose "o" if delta:z < -0.5 else "") +
                (choose "x" if delta:z > 0.5 else "").
        }
    }
}

local mannode_maneuver_time is 0.

// function that sets nav parameters to execute present/future nodes
local function orb_mannode {

    orb_stick().

    local steer_time is 10. // get from orb if possible
    local buffer_time is 1.
    local no_steer_dv is 0.1.
    if ISACTIVEVESSEL and HASNODE {
        local mannode_delta_v is NEXTNODE:deltav:mag.
        if defined AP_ORB_ENABLED {
            set mannode_maneuver_time to ap_orb_maneuver_time(NEXTNODE:deltav,thrust_vector).
            set steer_time to ap_orb_steer_time(NEXTNODE:deltav).
            set no_steer_dv to ap_orb_rcs_dv().
        }

        set AP_NAV_ACC to V(0,0,0).
        if NEXTNODE:eta < mannode_maneuver_time/2 + buffer_time {
            if mannode_delta_v < 0.01 {
                print "remaining node " + char(916) + "v " + round_fig(mannode_delta_v,3) + " m/s".
                set mannode_maneuver_time to 0.
                set AP_NAV_VEL to ship:velocity:orbit.
                set AP_NAV_ATT to ship:facing.
                REMOVE NEXTNODE.
            } else {
                // do burn
                set AP_NAV_VEL to ship:velocity:orbit + NEXTNODE:deltav.
                if NEXTNODE:deltav:mag > no_steer_dv {
                    local omega is -1*vcrs(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
                    local omega_mag is vectorAngle(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
                    set AP_NAV_ATT to angleaxis( omega_mag, omega:normalized )*ship:facing.
                }
            }
        } else if NEXTNODE:eta < mannode_maneuver_time/2 + buffer_time + steer_time {
            // steer to burn direction
            if not (kuniverse:timewarp:rate = 0) {
                set kuniverse:timewarp:rate to 0.
            }
            set AP_NAV_VEL to ship:velocity:orbit.
            local omega is -1*vcrs(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
            local omega_mag is vectorAngle(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
            set AP_NAV_ATT to angleaxis( omega_mag, omega:normalized )*ship:facing.
        } else {
            // do nothing
            set AP_NAV_VEL to ship:velocity:orbit.
            set AP_NAV_ATT to ship:facing.
        }
        
        return true.
    } else {
        set mannode_maneuver_time to 0.
        return false.
    }
}

// NAV ORB END

// NAV TAR START

local INTERCEPT_DISTANCE is get_param(PARAM, "MAX_TARGET_INTERCEPT_DISTANCE", 1200).
local MAX_STATION_KEEP_SPEED is get_param(PARAM, "MAX_STATION_KEEP_SPEED", 1.0).

local approach_speed is 0.
local position is V(0,0,0).
local final_head is R(0,0,0).

local relative_velocity is V(0,0,0).
local slow_roll is 0.
local relative_roll is 0.

local function tar_wp_guide {
    parameter wp.

    if not (wp["mode"] = "tar") {
        return false.
    }

    local new_roll is relative_roll.
    if wp:haskey("roll") {
        set new_roll to wp["roll"].
    } else if defined AP_MODE_ENABLED and AP_MODE_NAV {
        local delta_slow is sign(deadzone(ship:control:pilotroll,0.5)).
        set slow_roll to slow_roll+0.25*delta_slow.
        set new_roll to 15*round_dec(slow_roll,0).
    }
    if new_roll <> relative_roll {
        set relative_roll to new_roll.
        print "tar roll " + relative_roll.
    }

    local radius is max(get_param(wp, "radius", 1.0), 0.05).
    set approach_speed to get_param(wp, "speed", 3.0).
    local offsvec is get_param(wp, "offsvec", V(0,0,-abs(radius)) ).

    local target_ship is -1.
    if defined UTIL_SHSYS_ENABLED {
        set target_ship to util_shsys_get_target().
    } else if HASTARGET {
        set target_ship to TARGET.
    }

    if not (target_ship = -1) {
        set relative_velocity to get_vessel_vel()-get_vessel_vel(target_ship).
        set final_head to target_ship:facing*(choose R(0,0,0) if target_ship:hassuffix("velocity") else R(0,180,0)).
        local position is -ship:controlpart:position + target_ship:position + (final_head)*offsvec.
        if position:mag > INTERCEPT_DISTANCE {
            return false. // do nothing
        }
        nav_check_done(approach_speed, position, ship:facing, relative_velocity, radius).
        if approach_speed <= MAX_STATION_KEEP_SPEED {
            set approach_speed to sat(position:mag/radius, 1)*abs(approach_speed).
        }

        local align_data is nav_align(approach_speed, position, final_head, relative_velocity, radius).

        set AP_NAV_VEL to align_data[0]+get_vessel_vel(target_ship).
        set AP_NAV_ACC to align_data[1].
        set AP_NAV_ATT to final_head*R(0,0,-relative_roll).

        return true.
    } else {
        return false.
    }
}

// NAV TAR END

// NAV TEST START

// directly set any nav data here for testing
local function navtest_wp {
    parameter wp.

    if not (wp["mode"] = "navtest") {
        return false.
    }
    set AP_NAV_VEL to ship:velocity:surface.
    set AP_NAV_ACC to (-(vectorexclude(ship:up:vector,ship:velocity:orbit):mag^2)*ship:up:forevector +
            + 2*(ship:geoposition:velocity:orbit:mag)*vectorExclude(ship:up:vector,ship:velocity:orbit):normalized*(ship:velocity:orbit*ship:up:vector))/(ship:body:radius + ship:altitude).
    set AP_NAV_ATT to lookDirUp(ship:velocity:surface,ship:up:vector)*R(-12.5,0,0).

    if false {
        util_hud_push_left( "navtest",
            "a/g " + round_dec(get_acc():mag/GRAV_ACC:mag,3) + char(10) +
            "ang " + round_dec(vectorAngle(get_acc(),GRAV_ACC),3)).
        set nav_debug_vec1 to VECDRAW(V(0,0,0), 10*(get_acc()-GRAV_ACC), RGB(0,1,1),
            "", 1.0, true, 0.25, true ).
        set nav_debug_vec2 to VECDRAW(V(0,0,0), 10*GRAV_ACC, RGB(0,0,1),
            "", 1.0, true, 0.25, true ).
        set nav_debug_vec3 to VECDRAW(V(0,0,0), 10*get_acc(), RGB(1,1,1),
            "", 1.0, true, 0.25, true ).
    }
    return true.
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

    if cur_wayp["mode"] = "srf" and srf_wp_guide(cur_wayp) {
        set DISPLAY_SRF to true.

    } else if cur_wayp["mode"] = "orb" and orb_wp_guide(cur_wayp) {
        set DISPLAY_ORB to true.
    } else if cur_wayp["mode"] = "tar" and tar_wp_guide(cur_wayp) {
        set DISPLAY_TAR to true.
    } else if cur_wayp["mode"] = "navtest" and navtest_wp(cur_wayp) {
         set DISPLAY_SRF to AP_NAV_IN_SURFACE.
         set DISPLAY_ORB to AP_NAV_IN_ORBIT.
    } else if AP_NAV_IN_ORBIT and orb_mannode() {
        set DISPLAY_ORB to true.
    } else if AP_NAV_IN_SURFACE and srf_stick() {
        set DISPLAY_SRF to true.
    } else {
        set AP_NAV_VEL to get_vessel_vel().
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
            set nav_debug_vec_vel to VECDRAW(V(0,0,0), 30*(AP_NAV_VEL-get_vessel_vel(TARGET)), RGB(1,0,1),
                "", 1.0, true, 0.5, true ).
        } else {
            set nav_debug_vec_vel to VECDRAW(V(0,0,0), 30*get_vessel_vel(), RGB(0,1,0),
                "", 1.0, true, 0.5, true ).
        }
        set nav_debug_vec_vel_err to VECDRAW(V(0,0,0), 30*(AP_NAV_VEL-get_vessel_vel()), RGB(1,0,0),
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

local last_hud_vel is V(0,0,0).
function ap_nav_get_hud_vel {
    if DISPLAY_HUD_VEL {
        set DISPLAY_HUD_VEL to false.
        local orb_srf_vel is ship:geoposition:altitudevelocity(ship:altitude):orbit.
        if ISACTIVEVESSEL {
            if NAVMODE = "TARGET" and HASTARGET {
                set last_hud_vel to AP_NAV_VEL-get_vessel_vel(TARGET).
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
    return ( (AP_NAV_VEL-get_vessel_vel()) + 4*AP_NAV_ACC )*AP_NAV_VEL:normalized.
}

function ap_nav_status_string {
    local dstr is "".
    local mode_str is "".
    local vel_mag is ap_nav_get_hud_vel():mag.

    if DISPLAY_SRF {
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
    }

    if DISPLAY_ORB {
        if mannode_maneuver_time <> 0 {
            set dstr to char(10) + char(916) + "v " +round_fig((AP_NAV_VEL-ship:velocity:orbit):mag,2)
                + "|" + thrust_string + round_fig(mannode_maneuver_time,2) + "s " +
                + (choose char(10) + "T " + round_fig(-NEXTNODE:eta,2) + "s" if HASNODE else "").
        }
        set DISPLAY_ORB to false.
        set mode_str to mode_str + "o".
    }

    if DISPLAY_TAR {
        set dstr to dstr + "/"+round_fig(vel_mag,2).
        set DISPLAY_TAR to false.
        set mode_str to mode_str + "t".
    }

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
