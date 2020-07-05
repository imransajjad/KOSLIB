
GLOBAL AP_AERO_ENGINES_ENABLED IS true.


local PARAM is readJson("1:/param.json")["AP_AERO_ENGINES"].

local TOGGLE_X is get_param(PARAM,"TOGGLE_X", 0).
local TOGGLE_Y is get_param(PARAM,"TOGGLE_Y", 0).
local TOGGLE_VEL is get_param(PARAM,"TOGGLE_VEL", 0).
local V_PID_KP is get_param(PARAM,"V_PID_KP", 0.01).
local V_PID_KI is get_param(PARAM,"V_PID_KI", 0.004).
local V_PID_KD is get_param(PARAM,"V_PID_KD", 0).
local AUTO_BRAKES is get_param(PARAM,"AUTO_BRAKES", false).
local MAIN_ENGINE_NAME is get_param(PARAM,"MAIN_ENGINE_NAME", "").

local USE_GCAS is get_param(PARAM, "USE_GCAS", false).
local GCAS_SPEED is get_param(PARAM, "GCAS_SPEED", 200).

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

local lock MAX_TMR TO ap_aero_engines_get_total_thrust()/SHIP:MASS.

local lock vel to ship:airspeed.

local my_throttle is 0.0.

local vpid is PIDLOOP(
    V_PID_KP,
    V_PID_KI,
    V_PID_KD,
    0.0, 1.0).



function ap_aero_engines_get_total_thrust {
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

local auto_brakes_used is false.
local function apply_auto_brakes {
    parameter v_set.
    if AUTO_BRAKES and not GEAR {
        set auto_brakes_used to true.
        if BRAKES {
            set BRAKES to ( V_PID_KP*(v_set - vel) < -0.5  ) and 
                ship:facing:vector*ship:srfprograde:vector > 0.990. //~cos(2.5d)
        } else {
            set BRAKES to ( V_PID_KP*(v_set - vel) < -1.5  ) and 
                ship:facing:vector*ship:srfprograde:vector > 0.990.
        }
    } else if auto_brakes_used {
        set BRAKES to false.
        set auto_brakes_used to false.
    }
}

// Engine Specific functions

local function turbojet_throttle_map {
    parameter u0.
    if not is_active_vessel() {
        return my_throttle.
    }

    local MaxDryThrottle_x is TOGGLE_X-0.05.

    IF NOT (MAIN_ENGINES:length = 0){
        IF u0 > TOGGLE_X and MAIN_ENGINES[0]:MODE = "Dry"
        { for e in MAIN_ENGINES {e:TOGGLEMODE().}}
        IF u0 <= TOGGLE_X and MAIN_ENGINES[0]:MODE = "Wet"
        { for e in MAIN_ENGINES {e:TOGGLEMODE().}}
    }

    if u0 <= MaxDryThrottle_x {
        SET my_throttle TO (u0/MaxDryThrottle_x).
    } else if u0 <= TOGGLE_X and u0 > MaxDryThrottle_x{
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
        local ab_on is (v_set > TOGGLE_VEL or V_PID_KP*(v_set - vel) > 3.0).
        IF ab_on and MAIN_ENGINES[0]:MODE = "Dry"
        { for e in MAIN_ENGINES {e:TOGGLEMODE().}}
        IF not ab_on and MAIN_ENGINES[0]:MODE = "Wet"
        { for e in MAIN_ENGINES {e:TOGGLEMODE().}}
    }

    set vpid:setpoint to v_set.
    set my_throttle to vpid:update(time:seconds, vel).
    
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

function ap_aero_engine_throttle_auto {
    parameter vel_r is V(0,0,0).
    parameter acc_r is -1.
    parameter head_r is -1.
    // this function depends on AP_NAV_ENABLED
    if USE_GCAS and (ap_aero_rot_gcas_check()) {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(vel_r:mag).
    }
    apply_auto_brakes(vel_r:mag).
    common_func().
}

function ap_aero_engine_throttle_map {
    parameter input_throttle is SHIP:CONTROL:PILOTMAINTHROTTLE.
    if USE_GCAS and (ap_aero_rot_gcas_check()) {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func:call(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE TO mapped_throttle_func:call(input_throttle).
    }
    common_func().
}
