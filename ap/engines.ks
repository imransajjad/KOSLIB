
IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED is false.}
GLOBAL AP_ENGINES_ENABLED IS true.

// required global, will not modify
// pilot_input_u0
// main_engine_name


function ap_engines_get_total_thrust {
    local total_thrust is 0.
    for e in main_engine_list {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    return total_thrust.
}

local lock MAX_TMR TO ap_engines_get_total_thrust()/SHIP:MASS.

local my_throttle is 0.0.

local vpid is PIDLOOP(
    AP_ENGINES_V_PID_KP,
    AP_ENGINES_V_PID_KI,
    AP_ENGINES_V_PID_KD,
    0.0,1.0).



local function no_map {
    parameter u0.
    set my_throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    return max(my_throttle,0.0).
}

local function generic_throttle_auto {
    parameter v_set.
    set vpid:setpoint to v_set.
    set my_throttle to vpid:update(time:seconds, vel).
    return max(my_throttle,0.001).
}

local function turbojet_throttle_map {
    parameter u0.
    if not is_active_vessel() {
        return my_throttle.
    }

    local MaxDryThrottle_x is AP_ENGINES_TOGGLE_X-0.05.

    IF NOT (MAIN_ENGINES:length = 0){
        IF u0 > AP_ENGINES_TOGGLE_X AND MAIN_ENGINES[0]:MODE = "Dry"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
        IF u0 <= AP_ENGINES_TOGGLE_X AND MAIN_ENGINES[0]:MODE = "Wet"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
    }

    if u0 <= MaxDryThrottle_x {
        SET my_throttle TO (u0/MaxDryThrottle_x).
    } else if u0 <= AP_ENGINES_TOGGLE_X AND u0 > MaxDryThrottle_x{
        SET my_throttle TO 1.0.
    } else if u0 > AP_ENGINES_TOGGLE_X {
        SET my_throttle TO ((1-AP_ENGINES_TOGGLE_Y)*u0 + 
            (AP_ENGINES_TOGGLE_Y-AP_ENGINES_TOGGLE_X))/(1-AP_ENGINES_TOGGLE_X).
    }

    return max(my_throttle,0.0).
}

local function turbojet_throttle_auto {
    parameter v_set.
    IF NOT (MAIN_ENGINES:length = 0){
        IF v_set > AP_ENGINES_TOGGLE_VEL AND MAIN_ENGINES[0]:MODE = "Dry"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
        IF v_set <= AP_ENGINES_TOGGLE_VEL AND MAIN_ENGINES[0]:MODE = "Wet"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
    }

    set vpid:setpoint to v_set.
    set my_throttle to vpid:update(time:seconds, vel).
    return max(my_throttle,0.001).
}



local MAIN_ENGINES is get_engines(main_engine_name).

local auto_throttle_func is generic_throttle_auto@.
local mapped_throttle_func is no_map@.

FUNCTION ap_engine_throttle_auto {
    SET SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(ap_nav_get_vel()).
}

FUNCTION ap_engine_throttle_map {
    SET SHIP:CONTROL:MAINTHROTTLE TO mapped_throttle_func:call(pilot_input_u0).
}

function ap_engine_init {
    set MAIN_ENGINES to get_engines(main_engine_name).
    if main_engine_name = "turboJet" {
        if AP_NAV_ENABLED {
            set auto_throttle_func to turbojet_throttle_auto@.
            set mapped_throttle_func to turbojet_throttle_map@.
        } else {
            set auto_throttle_func to turbojet_throttle_map@.
            set mapped_throttle_func to turbojet_throttle_map@.
        }    
    }
}