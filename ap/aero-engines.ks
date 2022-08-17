
GLOBAL AP_AERO_ENGINES_ENABLED IS true.


local PARAM is get_param(readJson("param.json"), "AP_AERO_ENGINES", lexicon()).

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

local my_throttle is 0.0. // has to be accessible outside functions it seems
local last_stage is 9999.
local max_thrust is 1.0*SHIP:MASS.

local function get_total_tmr {
    local total_thrust is 0.
    if last_stage <> STAGE:number {
        set last_stage to STAGE:number.
        set MAIN_ENGINES to get_engines(MAIN_ENGINE_NAME).
    }
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    return total_thrust/SHIP:MASS.
}

local function attempt_restart {
    for e in MAIN_ENGINES {
        if not e:ignition {
            e:activate.
        }
    }
}

// initial generic maps / auto throttles

local function no_map {
    parameter u0.
    if not ISACTIVEVESSEL {
        return my_throttle.
    }

    local MAX_TMR is get_total_tmr().
    set my_throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    set max_thrust to MAX_TMR*ship:mass.
    return my_throttle.
}

local function generic_throttle_auto {
    parameter vel_r.
    parameter acc_r is 0.

    local a_set is acc_r + K_V*(vel_r - ship:airspeed).
    local a_applied is (-get_pre_aero_acc()*ship_vel_dir:vector + g0*sin(vel_pitch) + a_set).
    local MAX_TMR is get_total_tmr().
    set my_throttle to max(0.001,(choose a_applied/MAX_TMR if MAX_TMR > 0 else 0)).
    set max_thrust to MAX_TMR*ship:mass.
    set BRAKES to apply_auto_brakes(a_applied).

    if false {
        util_hud_push_left("generic_throttle_auto",
            "a/" + char(916) + " " + round_dec(a_set,2) + "/" + round_dec(a_set-get_acc()*ship_vel_dir:vector,4) + char(10) +
            "th/Tmax " + round_dec(my_throttle,3) + "/" + round_dec(max_thrust,3) + char(10) +
            "T_act " + round_dec(ap_aero_engines_get_current_thrust()*ship_vel_dir:vector,3)+ char(10) +
            "a_app " + round_dec(a_applied,3) ).
    }

    return my_throttle.
}

local function generic_common {
    return.
}

local auto_brakes_used is false.
local function apply_auto_brakes {
    parameter acc_applied.
    if AUTO_BRAKES and not (GEAR and ship:status = "flying") {
        set auto_brakes_used to true.
        local airflow_good is (abs(alpha) < 10 and abs(beta) < 15).
        if BRAKES {
            return ( acc_applied < -0.1  ) and airflow_good.
        } else {
            return ( acc_applied < -0.5  ) and airflow_good.
        }
    } else if auto_brakes_used {
        set auto_brakes_used to false.
        return false.
    }
    return false.
}

// Engine Specific functions

local last_dry_tmr is 0.5.
local last_wet_tmr is 1.0.
local lock dry_wet_ratio to max(0.001,last_dry_tmr)/max(0.01,last_wet_tmr).
local function turbojet_throttle_map {
    parameter u0.
    if not ISACTIVEVESSEL {
        return my_throttle.
    }

    local toggle_x is min(0.5 +0.5*dry_wet_ratio, 0.975).
    local toggle_y is dry_wet_ratio.
    local MaxDryThrottle_x is toggle_x-0.05.
    local MAX_TMR is get_total_tmr().

    if not (MAIN_ENGINES:length = 0){
        if MAIN_ENGINES[0]:mode = "Dry" {
            set max_thrust to MAX_TMR*ship:mass/dry_wet_ratio.
        } else {
            set max_thrust to MAX_TMR*ship:mass.
        }
        if u0 > toggle_x and MAIN_ENGINES[0]:MODE = "Dry" {
            set last_dry_tmr to MAX_TMR.
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
        } else if u0 <= toggle_x and MAIN_ENGINES[0]:MODE = "Wet" {
            set last_wet_tmr to MAX_TMR.
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
        }
    }

    if u0 <= MaxDryThrottle_x {
        SET my_throttle TO (u0/MaxDryThrottle_x).
    } else if u0 <= toggle_x and u0 > MaxDryThrottle_x{
        SET my_throttle TO 1.0.
    } else if u0 > toggle_x {
        SET my_throttle TO ((1-toggle_y)*u0 + 
            (toggle_y-toggle_x))/(1-toggle_x).
    }

    return my_throttle.
}

local function turbojet_throttle_auto {
    parameter vel_r.
    parameter acc_r is 0.

    local a_set is acc_r + K_V*(vel_r - ship:airspeed).
    local a_applied is (-get_pre_aero_acc()*ship_vel_dir:vector + g0*sin(vel_pitch) + a_set).
    local MAX_TMR is get_total_tmr().
    set my_throttle to max(0.001,(choose a_applied/MAX_TMR if MAX_TMR > 0 else 0)).
    set BRAKES to apply_auto_brakes(a_applied).

    if false {
        util_hud_push_left("turbojet_throttle_auto",
            "a/" + char(916) + " " + round_dec(a_set,2) + "/" + round_dec(a_set-get_acc()*ship_vel_dir:vector,4) + char(10) +
            "th/Tmax " + round_dec(my_throttle,3) + "/" + round_dec(max_thrust,3) + char(10) +
            "T_act " + round_dec(ap_aero_engines_get_current_thrust()*ship_vel_dir:vector,3)+ char(10) +
            "a_app " + round_dec(a_applied,3) ).
    }
    
    if not (MAIN_ENGINES:length = 0) {
        if MAIN_ENGINES[0]:mode = "Dry" {
            set max_thrust to MAX_TMR*ship:mass/dry_wet_ratio.
        } else {
            set max_thrust to MAX_TMR*ship:mass.
        }
        if (my_throttle > 1.00) and MAIN_ENGINES[0]:MODE = "Dry" {
            set last_dry_tmr to MAX_TMR.
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
        } else if (my_throttle < dry_wet_ratio ) and MAIN_ENGINES[0]:MODE = "Wet" {
            set last_wet_tmr to MAX_TMR.
            for e in MAIN_ENGINES {e:TOGGLEMODE().}
        }
    }
    return my_throttle.
}


local forward_thrust is true.
local function turbofan_common {
    if my_throttle <= 0.0 and brakes and ship:airspeed > 25 and abs(vel_pitch) < 2.5 {
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
    if SAS { return.}
    if USE_GCAS and (ap_gcas_check()) {
        attempt_restart().
        set SHIP:CONTROL:MAINTHROTTLE to auto_throttle_func(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE to auto_throttle_func(vel_r:mag, acc_r*ship:srfprograde:vector).
    }
    common_func().
}

function ap_aero_engine_throttle_map {
    parameter input_throttle is SHIP:CONTROL:PILOTMAINTHROTTLE.
    if SAS { return.}
    if USE_GCAS and (ap_gcas_check()) {
        attempt_restart().
        set SHIP:CONTROL:MAINTHROTTLE to auto_throttle_func(GCAS_SPEED).
    } else {
        set SHIP:CONTROL:MAINTHROTTLE to mapped_throttle_func(input_throttle).
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
