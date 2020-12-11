

local Ts is 0.04.
local minimum_intercept is 100.
local parent is ship.

local lock ship_vel to (-SHIP:FACING)*ship:velocity:surface:direction.
local lock alpha to wrap_angle(ship_vel:pitch).
local lock beta to wrap_angle(-ship_vel:yaw).

local function get_true_intercept_error {
    parameter cur_target.
    IF (cur_target = 0){
        return 10000000.
    }
    ELSE {
        set ATT TO constant:e^(-0.08*ship:dynamicpressure/ship:mass).
        set theta TO -(vectorangle(cur_target:direction:vector,UP:vector)-90).
        set vx TO ATT*ship:airspeed*cos(vel_pitch).
        set vy TO ATT*ship:airspeed*sin(vel_pitch).
        set h TO cur_target:distance*sin(theta).
        set d TO cur_target:distance*cos(theta).
        set g TO 9.81.

        set disc TO 1-2*g*h/(vy*vy).
        if (disc < 0) {set t TO (vy/g)*(1). }
        ELSE{ set t TO (vy/g)*(1+SQRT(1-2*g*h/(vy*vy))). }

        set x_error to d-vx*t.
        set lat_error to 0.1*constant:DegToRad*ABS(d*cur_target:bearing).
        //print x_error + lat_error .
        //print theta .
        return x_error + lat_error.
    }
}

// local target_vessel is -1.
function ap_missile_cache_target {
//     if ISACTIVEVESSEL and HASTARGET {
//         set target_vessel to TARGET.
//         print "target locked: "+ target_vessel:NAME.
//     }
}

function ap_missile_setup_separate {
    util_shbus_tx_msg("HUD_POPL",list(core:tag)).
    util_shbus_tx_msg("SYS_CB_OPEN",list(core:tag)).
    wait 2.0.

    set DELTA_FACE_AWAY to R(90,0,0)*(-ship:UP)*
        angleaxis(20,ship:facing:starvector)*(ship:facing).
    set pitch_init to (mod(DELTA_FACE_AWAY:pitch+90,180)-90).
    set yaw_init to (360-DELTA_FACE_AWAY:yaw).
    set roll_init to (180-DELTA_FACE_AWAY:roll).

    print pitch_init.
    print yaw_init.
    print roll_init.

    util_shbus_tx_msg("SYS_PL_AWAY",list(core:tag)).
    get_ancestor_with_module("ModuleReactionWheel"):getmodule("ModuleReactionWheel"):doaction("activate wheel", true).
    get_ancestor_with_module("ModuleDecouple"):getmodule("ModuleDecouple"):doevent("Decouple").
    wait Ts.
    wait Ts.

    lock steering TO heading(yaw_init,pitch_init,roll_init).

    until parent:distance > 3 {
        wait Ts.
    }

    set get_ancestor_with_module("ModuleEnginesFX"):thrustlimit to 100.
    set throttle to 1.0.
    lock throttle to my_throttle.
    print "engine on".
    until parent:distance > 6 {
        wait Ts.
    }.
}

local my_throttle is 0.0.
function ap_missile_guide {

    sas off.
    local PARAM is lexicon().
    if true {
    set STEERINGMANAGER:PITCHPID:KP to get_param(PARAM, "P_KP", 8.0).
    set STEERINGMANAGER:PITCHPID:KI to get_param(PARAM, "P_KI", 8.0).
    set STEERINGMANAGER:PITCHPID:KD to get_param(PARAM, "P_KD", 12.0).

    set STEERINGMANAGER:YAWPID:KP to get_param(PARAM, "Y_KP", 8.0).
    set STEERINGMANAGER:YAWPID:KI to get_param(PARAM, "Y_KI", 8.0).
    set STEERINGMANAGER:YAWPID:KD to get_param(PARAM, "Y_KD", 12.0).

    set STEERINGMANAGER:ROLLPID:KP to get_param(PARAM, "R_KP", 8.0).
    set STEERINGMANAGER:ROLLPID:KI to get_param(PARAM, "R_KI", 8.0).
    set STEERINGMANAGER:ROLLPID:KD to get_param(PARAM, "R_KD", 12.0).
    print "got gains".
}

    lock throttle to my_throttle.
    set my_throttle to 1.0.
    local target_vessel is util_shsys_get_target().
    if target_vessel = -1 {
        print "trying for 30 sec eta apoapsis".
        util_fldr_send_event("trying for 30 sec eta apoapsis").
        set yaw_init to yaw.
        lock steering TO heading(yaw_init,30,0).
        until ((eta:apoapsis >= 30) AND (eta:apoapsis < 90)) OR (ship:liquidfuel <= 1) {
            wait Ts.
        }
        print "eta Ap: "+eta:apoapsis.
        util_fldr_send_event("eta Ap: "+ round_dec(eta:apoapsis,1)).
        lock steering TO heading(vel_bear,vel_pitch,0).
        until (ship:liquidfuel <= 1) {
            wait Ts.
        }
        print "eta Ap: "+ eta:apoapsis.
        print "Ap: "+ ship:ORBIT:apoapsis.
        util_fldr_send_event("Ap: "+ round_dec(ship:ORBIT:apoapsis,0) + ", eta: " + round_dec(eta:apoapsis,1)).

        until false {
            wait Ts.
        }

    } else if target_vessel:status = "LANDED" or target_vessel:status = "SPLASHED" {
        local lock DELTA_TARGET to R(90,0,0)*(-SHIP:UP)*(target_vessel:direction).
        local lock target_pitch to (mod(DELTA_TARGET:pitch+90,180)-90).
        local lock target_bear to (360-DELTA_TARGET:yaw).

        print "entering guidance loop 1".
        util_fldr_send_event("entering guidance loop 1").
        lock steering TO heading(target_bear,30,0).
        until ((eta:apoapsis >= 30) AND (eta:apoapsis < 90)) OR (ship:liquidfuel <= 1) 
        OR (get_true_intercept_error(target_vessel) < minimum_intercept) {
            wait Ts.
        }
        print "Intercept Error: "+get_true_intercept_error(target_vessel).
        util_fldr_send_event("Intercept Error: "+get_true_intercept_error(target_vessel)).

        print "entering guidance loop 2".
        util_fldr_send_event("entering guidance loop 2").
        lock steering TO heading(target_bear,vel_pitch,0).
        until (get_true_intercept_error(target_vessel) < minimum_intercept) {
            wait Ts.
        }
        set my_throttle to 0.0.

        print "entering guidance loop 3".
        util_fldr_send_event("entering guidance loop 3").
        lock steering TO heading(target_bear,vel_pitch,0).
        until ((vectorangle(ship:facing:vector,target_vessel:DIRECTION:vector) < 5) OR
            (target_vessel:DISTANCE < 2500)) {
            wait Ts.
        }

        print "entering terminal guidance".
        util_fldr_send_event("entering terminal guidance").
        // unlock throttle.
        // unlock steering.
        // return.

        lock steering TO heading(target_bear,target_pitch+alpha,0).
        

        until FALSE{
            set my_throttle to (choose 1.0 if ship:q < 0.7 else 0.0).
            wait Ts.
        }
    } else if target_vessel:status = "FLYING" or target_vessel:status = "SUB ORBITAL" {
        
        local lock DELTA_TARGET to R(90,0,0)*(-SHIP:UP)*(target_vessel:direction).
        local lock target_pitch to (mod(DELTA_TARGET:pitch+90,180)-90).
        local lock target_bear to (360-DELTA_TARGET:yaw).

        print "entering guidance loop 1".
        util_fldr_send_event("entering guidance loop 1").
        lock steering TO heading(target_bear,30,0).
        until ((eta:apoapsis >= 30) AND (eta:apoapsis < 90)) OR (ship:liquidfuel <= 1) 
        OR (get_true_intercept_error(target_vessel) < minimum_intercept) {
            wait Ts.
        }

        print "entering terminal guidance".
        util_fldr_send_event("entering terminal guidance").
        unlock throttle.
        unlock steering.
        return.
    }
}
