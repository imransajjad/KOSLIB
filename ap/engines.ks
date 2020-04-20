
GLOBAL AP_ENGINES_ENABLED IS true.


local PARAM is readJson("1:/param.json")["AP_ENGINES"].

local TOGGLE_X is (choose PARAM["TOGGLE_X"] if PARAM:haskey("TOGGLE_X") else 0).
local TOGGLE_Y is (choose PARAM["TOGGLE_Y"] if PARAM:haskey("TOGGLE_Y") else 0).
local TOGGLE_VEL is (choose PARAM["TOGGLE_VEL"] if PARAM:haskey("TOGGLE_VEL") else 0).
local V_PID_KP is (choose PARAM["V_PID_KP"] if PARAM:haskey("V_PID_KP") else 0.01).
local V_PID_KI is (choose PARAM["V_PID_KI"] if PARAM:haskey("V_PID_KI") else 0.004).
local V_PID_KD is (choose PARAM["V_PID_KD"] if PARAM:haskey("V_PID_KD") else 0).
local AUTO_BRAKES is (choose PARAM["AUTO_BRAKES"] if PARAM:haskey("AUTO_BRAKES") else 0).
local MAIN_ENGINE_NAME is (choose PARAM["MAIN_ENGINE_NAME"] if PARAM:haskey("MAIN_ENGINE_NAME") else 0).


local MAIN_ENGINES is get_engines(MAIN_ENGINE_NAME).

local auto_throttle_func is generic_throttle_auto@.
local mapped_throttle_func is no_map@.
local common_func is generic_common@.

if MAIN_ENGINE_NAME = "turboJet" {
    set auto_throttle_func to turbojet_throttle_auto@.
    set mapped_throttle_func to turbojet_throttle_map@.
} else if MAIN_ENGINE_NAME = "turboFanSize2" {
    set common_func to turbofan_common@.
}

local lock MAX_TMR TO ap_engines_get_total_thrust()/SHIP:MASS.

local my_throttle is 0.0.

local vpid is PIDLOOP(
    V_PID_KP,
    V_PID_KI,
    V_PID_KD,
    0.0, 1.0).



function ap_engines_get_total_thrust {
    local total_thrust is 0.
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    return total_thrust.
}

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

    local MaxDryThrottle_x is TOGGLE_X-0.05.

    IF NOT (MAIN_ENGINES:length = 0){
        IF u0 > TOGGLE_X AND MAIN_ENGINES[0]:MODE = "Dry"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
        IF u0 <= TOGGLE_X AND MAIN_ENGINES[0]:MODE = "Wet"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
    }

    if u0 <= MaxDryThrottle_x {
        SET my_throttle TO (u0/MaxDryThrottle_x).
    } else if u0 <= TOGGLE_X AND u0 > MaxDryThrottle_x{
        SET my_throttle TO 1.0.
    } else if u0 > TOGGLE_X {
        SET my_throttle TO ((1-TOGGLE_Y)*u0 + 
            (TOGGLE_Y-TOGGLE_X))/(1-TOGGLE_X).
    }

    return max(my_throttle,0.0).
}

local function turbojet_throttle_auto {
    parameter v_set.
    IF NOT (MAIN_ENGINES:length = 0){
        local ab_on is (v_set > TOGGLE_VEL or V_PID_KP*(ap_nav_get_vel() - vel) > 3.0).
        // local ab_off is (v_set < TOGGLE_VEL or V_PID_KP*(ap_nav_get_vel() - vel) < 2.0).
        IF ab_on and MAIN_ENGINES[0]:MODE = "Dry"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
        IF not ab_on and MAIN_ENGINES[0]:MODE = "Wet"
        { MAIN_ENGINES[0]:TOGGLEMODE(). }
    }

    set vpid:setpoint to v_set.
    set my_throttle to vpid:update(time:seconds, vel).
    
    if AUTO_BRAKES and not BRAKES {
        set BRAKES to ( V_PID_KP*(ap_nav_get_vel() - vel) < -1.5  ) and 
            ship:facing:vector*ship:srfprograde:vector > 0.99.
    } else if AUTO_BRAKES {
        set BRAKES to ( V_PID_KP*(ap_nav_get_vel() - vel) < -1.0  ) and 
            ship:facing:vector*ship:srfprograde:vector > 0.99.
    }
    return max(my_throttle,0.001).
}


local forward_thrust is true.
local function turbofan_common {
    if my_throttle <= 0.0 and brakes and vel > 25{
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

function ap_engine_throttle_auto {
    // this function depends on AP_NAV_ENABLED
    SET SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(ap_nav_get_vel()).
    common_func().
}

function ap_engine_throttle_map {
    parameter input_throttle is pilot_input_u0.
    SET SHIP:CONTROL:MAINTHROTTLE TO mapped_throttle_func:call(input_throttle).
    common_func().
}


