
IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED is false.}
GLOBAL AP_ENGINES_ENABLED IS true.

// required global, will not modify
// MAIN_ENGINES
// pilot_input_u0


local main_engine_list is LIST().
function ap_engines_get_mains {
    set main_engine_list to LIST().
    for e in SHIP:PARTSDUBBED(main_engine_name){
        main_engine_list:add(e).
        PRINT "Found Engine "+ e:NAME.
    }
    return main_engine_list.
}

function ap_engines_get_total_thrust {
    local total_thrust is 0.
    for e in main_engine_list {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    return total_thrust.
}

local lock MAX_TMR TO ap_engines_get_total_thrust()/SHIP:MASS.

local lock V_SET to ap_nav_get_vel().

// THROTTLE STUFF

local THROTTLE_MANUAL is FALSE.
local u0i is 0.0.
local MaxDryThrottle_x is 0.75.
local MinWetThrottle_x is 0.8.
local MinWetThrottle_y is 0.5.
local K_throttlei is 0.000025.
local K_throttle is 0.005.
local my_throttle is 0.0.


local function map_throttle {
    IF is_active_vessel() or util_wp_queue_length() > 0 {

        IF AP_NAV_ENABLED and not THROTTLE_MANUAL {
            IF NOT (MAIN_ENGINES:length = 0){
                if V_SET <= 0 {
                    SET u0i TO 0.
                    set my_throttle to 0.001.
                    return my_throttle.
                }
                SET u0i TO u0i + (V_SET-vel).

                SET u0 TO MAX_TMR*(K_throttle*(V_SET-vel) + K_throttlei*u0i).

                IF (u0 > 1.01) OR (u0 < -0.01) {
                    SET u0i TO u0i - (V_SET-vel).
                    SET u0 TO MAX_TMR*(K_throttle*(V_SET-vel) + K_throttlei*u0i).
                }
                SET my_throttle TO min(1.0, max(u0,0.001)).

                IF V_SET > 345 AND MAIN_ENGINES[0]:MODE = "Dry"
                { MAIN_ENGINES[0]:TOGGLEMODE(). }
                IF V_SET <= 345 AND MAIN_ENGINES[0]:MODE = "Wet"
                { MAIN_ENGINES[0]:TOGGLEMODE(). }
            }
        }
        // in plane and manual control
        IF THROTTLE_MANUAL and is_active_vessel() {
            IF pilot_input_u0 > MinWetThrottle_x {
                SET my_throttle TO ((1-MinWetThrottle_y)*pilot_input_u0 + 
                    (MinWetThrottle_y-MinWetThrottle_x))/(1-MinWetThrottle_x).
            }
            IF pilot_input_u0 <= MinWetThrottle_x AND pilot_input_u0 > MaxDryThrottle_x{
                SET my_throttle TO 1.0.
            }
            IF pilot_input_u0 <= MaxDryThrottle_x {
                SET my_throttle TO (pilot_input_u0/MaxDryThrottle_x).
            }
            IF NOT (MAIN_ENGINES:length = 0){
                IF pilot_input_u0 > MinWetThrottle_x AND MAIN_ENGINES[0]:MODE = "Dry"
                { MAIN_ENGINES[0]:TOGGLEMODE(). }
                IF pilot_input_u0 <= MinWetThrottle_x AND MAIN_ENGINES[0]:MODE = "Wet"
                { MAIN_ENGINES[0]:TOGGLEMODE(). }
            }
        }
    }
    RETURN my_throttle.
}

//UNLOCK THROTTLE.

FUNCTION ap_engine_throttle_auto {
    IF THROTTLE_MANUAL{
        SET THROTTLE_MANUAL TO FALSE.
    }
    SET SHIP:CONTROL:MAINTHROTTLE TO map_throttle().
}

FUNCTION ap_engine_throttle_map {
    IF NOT THROTTLE_MANUAL {
        //LOCK SHIP:CONTROL:MAINTHROTTLE TO map_throttle().
        SET THROTTLE_MANUAL TO TRUE.
    }
    SET SHIP:CONTROL:MAINTHROTTLE TO map_throttle().
}
