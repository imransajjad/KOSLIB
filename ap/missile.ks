


local engine is 0.
local decoupler_module is 0.
local probe_core is 0.
local reaction_wheels_module is 0.
local flcs_proc is processor("FLCS").

local Ts is 0.0001.
local minimum_intercept is 100.
local parent is ship.

local lock DELTA_FACE_UP TO R(90,0,0)*(-ship:UP)*(ship:facing).
local lock pitch TO (mod(DELTA_FACE_UP:pitch+90,180)-90).
local lock roll TO (180-DELTA_FACE_UP:roll).
local lock yaw TO (360-DELTA_FACE_UP:yaw).

local lock vel_pitch TO (mod((delta_pro_up()):pitch+90,180)-90).
local lock vel_bear TO (360-delta_pro_up():yaw).

local lock DELTA_ALPHA TO R(0,0,RAD2DEG*roll)*(-ship:srfprograde)*(ship:facing).
local lock alpha TO -(mod(DELTA_ALPHA:PITCH+180,360)-180).
local lock beta TO  mod(DELTA_ALPHA:YAW+180,360)-180.

local lock DELTA_TARGET TO R(90,0,0)*(-SHIP:UP)*(target_vessel:direction).
local lock target_pitch TO (mod(DELTA_TARGET:pitch+90,180)-90).
local lock target_bear TO (360-DELTA_TARGET:yaw).

local function get_engine_decoupler {
    set decoupler_module to 0.
    for p in ship:parts {
        if p:tag = core:tag+"_missile_engine" {
            set engine to p.
        } else if p:tag = core:tag+"_missile_decoupler" {
            set decoupler_module to p:getmodule("ModuleDecouple").
        }
    }
    if decoupler_module = 0 {
        print "decoupler not found ".
    }
    if engine = 0 {
        print "engine not found ".
    }
}


local function get_parts_used {
    for p in ship:parts {
        if p:title = "Probodobodyne OKTO2" {
            set probe_core to p.
        } else if p:title = "Small Inline Reaction Wheel" {
            set reaction_wheels_module to p:getmodule("ModuleReactionWheel").
        }
    }
    if engine = 0 or probe_core = 0 or reaction_wheels_module = 0 {
        print "parts not configured properly: e/c/rw " + engine +  probe_core + reaction_wheels_module.
    }
}


local function cargo_bay_open {
    IF NOT flcs_proc:CONNECTION:SENDMESSAGE(list("SYS_CB_OPEN",list(core:tag))) {
        print "could not CB_OPEN send message".
    }
}
local function cargo_bay_safe_close {
    IF NOT flcs_proc:CONNECTION:SENDMESSAGE(list("SYS_PL_AWAY",list(core:tag))) {
        print "could not PL_AWAY send message".
    }
}

local function send_q_unsafe {
    IF NOT flcs_proc:CONNECTION:SENDMESSAGE(list("HUD_PUSHL",list(core:tag, "nQS"))) {
        print "could not HUD_PUSHL send message".
    }
}

local function send_rem_q_unsafe {
    IF NOT flcs_proc:CONNECTION:SENDMESSAGE(list("HUD_POPL",list(core:tag))) {
        print "could not HUD_POPL send message".
    }
}


local Qsafe is TRUE.
local function is_Qsafe {
    IF (ship:dynamicpressure > 0.75) AND (Qsafe){
        set Qsafe TO FALSE.
        print "above launch Q limit".
        send_q_unsafe().
    }
    IF (ship:dynamicpressure < 0.75) AND (NOT Qsafe) {
        set Qsafe TO TRUE.
        print "Q safe".
        send_rem_q_unsafe().
    }
}

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

local target_vessel is 0.
local function get_target {
    IF HASTARGET {
        set target_vessel to TARGET.
        print "target locked: "+ target_vessel:NAME.
    }
}

local function print_com_offset {
    set off_vec to (ship:position - probe_core:position).
    print "top  " + off_vec*ship:facing:topvector.
    print "fore " + off_vec*ship:facing:forevector.
    print "star " + off_vec*ship:facing:starvector.
}

local function delta_pro_up {
    if ship:altitude > 35000 {
        return R(90,0,0)*(-ship:UP)*(ship:prograde).
    } else {
        return R(90,0,0)*(-ship:UP)*(ship:srfprograde).
    }
}

function ap_missile_init {
    get_engine_decoupler().
}

function ap_missile_wait {
    until engine:ignition  {
        is_Qsafe().
        wait Ts.
    }.
}

function ap_missile_setup_separate {
    get_target().
    send_rem_q_unsafe().
    cargo_bay_open().
    wait 2.0.

    set DELTA_FACE_AWAY to R(90,0,0)*(-ship:UP)*
        angleaxis(20,ship:facing:starvector)*(ship:facing).
    set pitch_init to (mod(DELTA_FACE_AWAY:pitch+90,180)-90).
    set yaw_init to (360-DELTA_FACE_AWAY:yaw).
    set roll_init to (180-DELTA_FACE_AWAY:roll).

    print pitch_init.
    print yaw_init.
    print roll_init.

    cargo_bay_safe_close().
    decoupler_module:Doevent("decouple").
    wait Ts.
    wait Ts.

    sas off.
    set STEERINGMANAGER:YAWPID:KP TO 8.0.
    set STEERINGMANAGER:PITCHPID:KP TO 8.0.
    set STEERINGMANAGER:ROLLPID:KP TO 8.0.
    set STEERINGMANAGER:YAWPID:KD TO 12.0.
    set STEERINGMANAGER:PITCHPID:KD TO 12.0.
    set STEERINGMANAGER:ROLLPID:KD TO 12.0.

    get_parts_used().
    probe_core:controlfrom().
    print_com_offset().
    reaction_wheels_module:doaction("activate wheel", true).

    lock steering TO heading(yaw_init,pitch_init,roll_init).

    until parent:distance > 3 {
        wait Ts.
    }

    set engine:thrustlimit to 100.
    set my_throttle to 1.0.
    lock throttle to my_throttle.
    print "engine on".
    until parent:distance > 6 {
        wait Ts.
    }.
}


function ap_missile_guide {    
    if target_vessel = 0 {
        print "trying for 30 sec eta apoapsis".
        set yaw_init to yaw.
        lock steering TO heading(yaw_init,30,0).
        until ((eta:apoapsis >= 30) AND (eta:apoapsis < 90)) OR (ship:liquidfuel <= 1) {
            wait Ts.
        }
        print "eta Ap: "+eta:apoapsis.
        lock steering TO heading(vel_bear,vel_pitch,0).
        until (ship:liquidfuel <= 1) {
            wait Ts.
        }
        print "eta Ap: "+ eta:apoapsis.
        print "Ap: "+ ship:ORBIT:apoapsis.

        until false {
            wait Ts.
        }

    } else {
        print "entering guidance loop 1".
        lock steering TO heading(target_bear,30,0).
        until ((eta:apoapsis >= 30) AND (eta:apoapsis < 90)) OR (ship:liquidfuel <= 1) 
        OR (get_true_intercept_error(target_vessel) < minimum_intercept) {
            wait Ts.
        }
        print "Intercept Error: "+get_true_intercept_error(target_vessel).

        print "entering guidance loop 2".
        lock steering TO heading(target_bear,vel_pitch,0).
        until (get_true_intercept_error(target_vessel) < minimum_intercept) {
            wait Ts.
        }
        set my_throttle to 0.0.

        print "entering guidance loop 3".
        lock steering TO heading(target_bear,vel_pitch,0).
        until ((vectorangle(ship:facing:vector,target_vessel:DIRECTION:vector) < 5) OR
            (target_vessel:DISTANCE < 2500)) {
            wait Ts.
        }

        print "entering terminal guidance".

        lock steering TO heading(target_bear,target_pitch+alpha,0).
        set my_throttle to 1.0.

        until FALSE{
            wait Ts.
        }
    }
}
