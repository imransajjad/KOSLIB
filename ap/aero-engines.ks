
GLOBAL AP_AERO_ENGINES_ENABLED IS true.


local PARAM is get_param(readJson("param.json"), "AP_AERO_ENGINES", lexicon()).

local TOGGLE_X is get_param(PARAM,"TOGGLE_X", 0).
local TOGGLE_Y is get_param(PARAM,"TOGGLE_Y", 0).
local K_V is get_param(PARAM,"K_V", 0.25).
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

local my_throttle is 0.0.

local max_thrust is 1.0/SHIP:MASS.
local lock MAX_TMR to get_total_tmr().

local function get_total_tmr {
    local total_thrust is 0.
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    set max_thrust to max(0.0001,total_thrust).
    return max_thrust/SHIP:MASS.
}

// initial generic maps / auto throttles

local function no_map {
    parameter u0.
    set my_throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    return max(my_throttle,0.0).
}

local function generic_throttle_auto {
    parameter vel_r.
    parameter acc_r is 0.

    set a_set to acc_r + K_V*(vel_r - ship:airspeed).
    set my_throttle to (-get_pre_aero_acc()*ship_vel_dir:vector + g0*sin(vel_pitch) + a_set)/MAX_TMR.

    // util_hud_push_left("generic_throttle_auto", "a/" + char(916) + " " + round_dec(a_set,2) + "/" + round_dec(a_set-get_acc()*ship_vel_dir:vector,4)
    //     + char(10) + "Tmax " + round_dec(max_thrust,2)
    //     + char(10) + "th/T " + round_dec(my_throttle*max_thrust,3) + "/" + round_dec(ap_aero_engines_get_current_thrust():mag,3) ).
        
    return max(my_throttle,0.001).
}

local function generic_common {
    return.
}

local auto_brakes_used is false.
local function apply_auto_brakes {
    parameter vel_r.
    parameter acc_r.
    if AUTO_BRAKES and not (GEAR and ship:status = "flying") {
        set auto_brakes_used to true.
        if BRAKES {
            set BRAKES to ( my_throttle < 0.05  ) and 
                ship:facing:vector*ship:srfprograde:vector > 0.990. //~cos(2.5d)
        } else {
            set BRAKES to ( my_throttle < -0.05  ) and 
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
    if not ISACTIVEVESSEL {
        return my_throttle.
    }

    local MaxDryThrottle_x is TOGGLE_X-0.05.

    if not (MAIN_ENGINES:length = 0){
        if u0 > TOGGLE_X and MAIN_ENGINES[0]:MODE = "Dry"
        { for e in MAIN_ENGINES {e:TOGGLEMODE().}}
        if u0 <= TOGGLE_X and MAIN_ENGINES[0]:MODE = "Wet"
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

local last_dry_tmr is 0.5.
local last_wet_tmr is 1.0.
local function turbojet_throttle_auto {
    parameter vel_r.
    parameter acc_r is 0.

    set a_set to acc_r + K_V*(vel_r - ship:airspeed).
    set my_throttle to (-get_pre_aero_acc()*ship_vel_dir:vector + g0*sin(vel_pitch) + a_set)/MAX_TMR.
    
    // util_hud_push_left("turbojet_throttle_auto", "a/" + char(916) + " " + round_dec(a_set,2) + "/" + round_dec(a_set-get_acc()*ship_vel_dir:vector,4)
    //     + char(10) + "Tmax " + round_dec(max_thrust,2)
    //     + char(10) + "th/T " + round_dec(my_throttle*max_thrust,3) + "/" + round_dec(ap_aero_engines_get_current_thrust():mag,3) ).
    
    if not (MAIN_ENGINES:length = 0) {
        set last_switch_time to time:seconds.
        if (my_throttle > 1.00) and MAIN_ENGINES[0]:MODE = "Dry"
        {
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
            set last_wet_tmr to MAX_TMR.
            }
        if (my_throttle < last_dry_tmr/last_wet_tmr ) and MAIN_ENGINES[0]:MODE = "Wet"
        {
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
            set last_dry_tmr to MAX_TMR.
        }
    }
    return max(my_throttle,0.001).
}


local forward_thrust is true.
local function turbofan_common {
    if my_throttle <= 0.0 and brakes and ship:airspeed > 25 {
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

// will try to achieve vel_r and acc_r in the engine/prograde direction.
// pass in vel_r = ship:airspeed for acceleration only control
function ap_aero_engine_throttle_auto {
    parameter vel_r is AP_NAV_VEL. // defaults are globals defined in AP_NAV
    parameter acc_r is AP_NAV_ACC.
    parameter head_r is AP_NAV_ATT.
    // this function depends on AP_NAV_ENABLED
    if USE_GCAS and (ap_gcas_check()) {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func(vel_r:mag, acc_r*ship:srfprograde:vector).
    }
    apply_auto_brakes(vel_r*ship:srfprograde:vector, acc_r*ship:srfprograde:vector).
    common_func().
}

function ap_aero_engine_throttle_map {
    parameter input_throttle is SHIP:CONTROL:PILOTMAINTHROTTLE.
    if USE_GCAS and (ap_gcas_check()) {
        set SHIP:CONTROL:MAINTHROTTLE TO auto_throttle_func(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE TO mapped_throttle_func(input_throttle).
    }
    common_func().
}

function ap_aero_engines_get_current_thrust {
    local total_thrust is V(0,0,0).
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:thrust*e:facing:forevector.
    }
    return total_thrust.
}

function ap_aero_engines_get_max_thrust {
    return max_thrust.
}
