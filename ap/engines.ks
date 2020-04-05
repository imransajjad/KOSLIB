
GLOBAL AP_ENGINES_ENABLED IS true.

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


// initial generic maps / auto throttles

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

local function generic_common {
    return.
}


// Engine Specific functions

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


local forward_thrust is true.
local function turbofan_common {
    if my_throttle <= 0 and brakes and vel > 25{
        if forward_thrust {
            set forward_thrust to false.
            for e in MAIN_ENGINES {
                e:getmodule("ModuleAnimateGeneric"):doaction("toggle thrust reverser", true).
            }
        }
    } else {
        if not forward_thrust {
            set forward_thrust to true.
            for e in MAIN_ENGINES {
                e:getmodule("ModuleAnimateGeneric"):doaction("toggle thrust reverser", true).
            }
        }
    }
    if not forward_thrust {
        SET SHIP:CONTROL:MAINTHROTTLE to 1.0.
    }
}

IF NOT (DEFINED MAIN_ENGINE_NAME) { set MAIN_ENGINE_NAME to "".}
local MAIN_ENGINES is get_engines(MAIN_ENGINE_NAME).

local auto_throttle_func is generic_throttle_auto@.
local mapped_throttle_func is no_map@.
local common_func is generic_common@.

function ap_engine_throttle_auto {
    SET SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(ap_nav_get_vel()).
    common_func().
}

function ap_engine_throttle_map {
    parameter input_throttle is pilot_input_u0.
    SET SHIP:CONTROL:MAINTHROTTLE TO mapped_throttle_func:call(input_throttle).
    common_func().
}

function ap_engine_init {
    set MAIN_ENGINES to get_engines(MAIN_ENGINE_NAME).

    if MAIN_ENGINE_NAME = "turboJet" {
        if (defined AP_NAV_ENABLED) and AP_NAV_ENABLED {
            set auto_throttle_func to turbojet_throttle_auto@.
            set mapped_throttle_func to turbojet_throttle_map@.
        } else {
            set auto_throttle_func to turbojet_throttle_map@.
            set mapped_throttle_func to turbojet_throttle_map@.
        }    
    } else if MAIN_ENGINE_NAME = "turboFanSize2" {
        set common_func to turbofan_common@.
    }

}
