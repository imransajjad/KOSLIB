
GLOBAL AP_AERO_ROT_ENABLED IS true.

local PARAM is readJson("param.json")["AP_AERO_ROT"].

// glimits
local GLIM_VERT is get_param(PARAM,"GLIM_VERT", 5).
local GLIM_LAT is get_param(PARAM,"GLIM_LAT", 1).
local GLIM_LONG is get_param(PARAM,"GLIM_LONG", 3).

local CORNER_VELOCITY is get_param(PARAM,"CORNER_VELOCITY", 200).


local RATE_SCHEDULE_ENABLED is get_param(PARAM,"RATE_SCHEDULE_ENABLED", false).
local START_MASS is get_param(PARAM,"START_MASS", 0).

local GAIN_SCHEDULE_ENABLED is get_param(PARAM,"GAIN_SCHEDULE_ENABLED", false).
local PITCH_SPECIFIC_INERTIA is get_param(PARAM,"PITCH_SPECIFIC_INERTIA", 0).

// rate limits
local MAX_ROLL is DEG2RAD*get_param(PARAM,"MAX_ROLL", 180).

// pitch rate PID gains
local PR_KP is get_param(PARAM,"PR_KP", 0).
local PR_KI is get_param(PARAM,"PR_KI", 0).
local PR_KD is get_param(PARAM,"PR_KD", 0).

// yaw rate PID gains
local YR_KP is get_param(PARAM,"YR_KP", 0).
local YR_KI is get_param(PARAM,"YR_KI", 0).
local YR_KD is get_param(PARAM,"YR_KD", 0).

// roll rate PID gains
local RR_KP is get_param(PARAM,"RR_KP", 0).
local RR_KI is get_param(PARAM,"RR_KI", 0).
local RR_KD is get_param(PARAM,"RR_KD", 0).

// USES AG6

local lock AG to AG6.

// AERO ROT PID STUFF

local lock vel to ship:airspeed.

local lock wg to vcrs(ship:velocity:surface:normalized, ship:up:vector)*
                (get_frame_accel_orbit()/max(1,vel)):mag.

local lock pitch_rate to -((SHIP:ANGULARVEL)*SHIP:FACING:STARVECTOR).
local lock yaw_rate to ((SHIP:ANGULARVEL+wg)*SHIP:FACING:TOPVECTOR).
local lock roll_rate to -((SHIP:ANGULARVEL)*SHIP:FACING:FOREVECTOR).


local lock LATOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:STARVECTOR.
local lock LONGOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:VECTOR.

local lock ship_vel to (-SHIP:FACING)*ship:velocity:surface:direction.
local lock alpha to wrap_angle(ship_vel:pitch).
local lock beta to wrap_angle(-ship_vel:yaw).

local function cl_sched {
    parameter v.

    if ( v < 100) {
        return -(5/100)*v + 8.5.
    } else if (v < 300) {
        return -(2.5/200)*v + 4.75.
    } else if (v < 2100) {
        return -(0.2/700)*v + 1.09.
    } else {
        return 0.49.
    }
}

local function cd_sched {
    parameter v.

    if (v < 50) {
        return 1.0.
    } else if ( v < 100) {
        return -(0.5/50)*v + 1.5.
    } else if (v < 300) {
        return 0.5.
    } else if (v < 400) {
        return (1.0/100)*v - 2.5.
    } else if (v < 500) {
        return -(0.3/100)*v + 2.7.
    } else {
        return 1.2.
    }
}

local MIN_AERO_Q is 0.0003.
local MIN_PITCH_RATE is 2.5*DEG2RAD.

local MIN_SEA_Q is 1.0*(50/420)^2.
local CORNER_SEA_Q is 1.0*(CORNER_VELOCITY/420)^2.
local W_V_MAX is (GLIM_VERT*g0/CORNER_VELOCITY).
local W_L_MAX is (GLIM_LAT*g0/CORNER_VELOCITY).

local WING_AREA is 0.

local lock GLimiter to ( prate_max+0.0001 + g0/vel*cos(vel_pitch)*cos(roll) >
    GLIM_VERT*g0/vel ).

local pratePID is PIDLOOP(
    PR_KP,
    PR_KI,
    PR_KD,
    -1.0,1.0).
local pitch_rate is 0.
if (RATE_SCHEDULE_ENABLED)
{
    set WING_AREA to W_V_MAX/
            (CORNER_SEA_Q*cl_sched(CORNER_VELOCITY))
            *(START_MASS*CORNER_VELOCITY).
    lock prate_max to 
        max(
            MIN_PITCH_RATE,
            min(
                WING_AREA*SHIP:DYNAMICPRESSURE*cl_sched(vel)/(ship:mass*vel),
                GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
} else {
    lock prate_max to max(
            MIN_PITCH_RATE,
            min(
                (vel/CORNER_VELOCITY)*W_V_MAX,
                GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
}

local yratePID is PIDLOOP(
    YR_KP,
    YR_KI,
    YR_KD,
    -1.0,1.0).
local lock yrate_max to MIN(
    W_L_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_SEA_Q),
    GLIM_LAT*g0/vel).

local rratePD is PIDLOOP(
    RR_KP,
    0,
    RR_KD,
    -1.0,1.0).

local rrateI is PIDLOOP(
    0,
    RR_KI,
    0,
    -0.05,0.05).

local lock rrate_max to sat(vel/CORNER_VELOCITY*MAX_ROLL, MAX_ROLL).


local LF2G is 1.0.
local prev_AG is AG.
local function gain_schedule {

    local loadfactor is max(ship:q,MIN_SEA_Q)/ship:mass.
    local alsat is sat(alpha,35).
    local airflow_c_u is cl_sched(max(50,vel))*(cos(alsat)^3 - 1*cos(alsat)*sin(alsat)^2)+
        cd_sched(max(50,vel))*(2*cos(alsat)*sin(alsat)^2).

    set LF2G to 1.0.

    if prev_AG <> AG {
        set prev_AG to AG.
        print "LF2G: " + round_dec(LF2G/(choose 3 if AG else 1),2).
    }
    if prev_AG {
        set LF2G to LF2G/3.
    }
    set LF2G to LF2G/(PITCH_SPECIFIC_INERTIA*loadfactor*airflow_c_u)/kuniverse:timewarp:rate.

    set pratePID:KP to PR_KP*LF2G.
    set pratePID:KI to PR_KI*LF2G.
    set pratePID:KD to PR_KD*LF2G.

    set yratePID:KP to YR_KP*LF2G.
    set yratePID:KI to YR_KI*LF2G.
    set yratePID:KD to YR_KD*LF2G.
    
    set rratePD:KP to RR_KP*LF2G.
    set rrateI:KI to RR_KI*LF2G.
    set rratePD:KD to RR_KD*LF2G.
}


local Vslast is 0.0.
local prev_land is SHIP:STATUS.
local function display_land_stats {
    if not (SHIP:STATUS = prev_land) {
        if SHIP:STATUS = "LANDED" {
            local land_stats is "landed" + char(10) +
                "  pitch "+ round_dec(pitch,2) + char(10) +
                "  v/vs  "+ round_dec(vel,2) + "/"+round_dec(Vslast,2).
            if UTIL_HUD_ENABLED {
                util_hud_push_left("AERO_ROT_LAND_STATS" , land_stats ).
            }
            if UTIL_FLDR_ENABLED {
                util_fldr_send_event(land_stats).
            }
            print land_stats.
        } else if SHIP:STATUS = "FLYING" {
            if UTIL_HUD_ENABLED {
                util_hud_pop_left("AERO_ROT_LAND_STATS").
            }
        }
        set prev_land to SHIP:STATUS.
    }
    if ship:status = "FLYING" {
        SET Vslast TO SHIP:VERTICALSPEED.
    }
}


local aero_active is true.
function ap_aero_rot_do {
    PARAMETER u1. // pitch
    PARAMETER u2. // yaw
    PARAMETER u3. // roll in radians/sec
    parameter direct_mode is false.
    // in direct_mode, u1,u2,u3 are expected to be direct rate values
    // else they are stick inputs

    IF not SAS and ship:q > MIN_AERO_Q {

        if GAIN_SCHEDULE_ENABLED {
            gain_schedule().
        }
        display_land_stats().

        if direct_mode {
            set pratePID:SETPOINT TO sat(u1,prate_max).
            set yratePID:SETPOINT TO sat(u2,yrate_max).
            set rratePD:SETPOINT TO sat(u3,rrate_max).
            set rrateI:SETPOINT TO sat(u3,rrate_max).
        } else {
            set pratePID:SETPOINT TO prate_max*u1.
            set yratePID:SETPOINT TO yrate_max*u2.
            set rratePD:SETPOINT TO rrate_max*u3.
            set rrateI:SETPOINT TO rrate_max*u3.
        }

        set SHIP:CONTROL:YAW TO yratePID:UPDATE(TIME:SECONDS, yaw_rate)
            +SHIP:CONTROL:YAWTRIM.

        local roll_pd is rratePD:UPDATE(TIME:SECONDS, roll_rate).
        local roll_i is 0.
        if (abs(u3) < 0.2) {
            set roll_i to rrateI:UPDATE(TIME:SECONDS, roll_rate).
        } else {
            rrateI:RESET().
        }

        set SHIP:CONTROL:ROLL TO ( roll_pd + roll_i ) +
            SHIP:CONTROL:ROLLTRIM.

        set SHIP:CONTROL:PITCH TO pratePID:UPDATE(TIME:SECONDS, pitch_rate)+
            SHIP:CONTROL:PITCHTRIM.

        if not aero_active {
            set aero_active to true.
        }
    } else {
        if aero_active {
            set aero_active to false.
            rrateI:RESET().
            yratePID:RESET().
            pratePID:RESET().
            SET SHIP:CONTROL:NEUTRALIZE to TRUE.
        }
    }
}

function ap_aero_rot_maxrates {
    return list(RAD2DEG*prate_max,RAD2DEG*yrate_max,RAD2DEG*rrate_max).
}

local departure is false.
function ap_aero_rot_status_string {

    local hud_str is "".

    if (ship:q > MIN_AERO_Q) {
        set hud_str to hud_str+( choose "GL " if GLimiter else "G ") +round_dec( vel*pitch_rate/g0 + 1.0*cos(vel_pitch)*cos(roll) ,1) + 
        char(10) + char(945) + " " + round_dec(alpha,1).
        if UTIL_FLDR_ENABLED {
            if abs(alpha) > 45 and not departure {
                util_fldr_send_event("aero_rot departure").
                set departure to true.
            } else if abs(alpha) < 20 and departure {
                set departure to false.
            }
        }
    }

    if ( false) { // pitch debug
    set hud_str to hud_str+
        char(10) + "ppid" + " " + round_dec(PR_KP,2) + " " + round_dec(PR_KI,2) + " " + round_dec(PR_KD,2) +
        char(10) + "pmax" + " " + round_dec(RAD2DEG*prate_max,1) +
        char(10) + "pask" + " " + round_dec(RAD2DEG*pratePID:SETPOINT,1) +
        char(10) + "pact" + " " + round_dec(RAD2DEG*pitch_rate,1) +
        char(10) + "perr" + " " + round_dec(RAD2DEG*pratePID:ERROR,1).
    }

    if ( false) { // roll debug
    set hud_str to hud_str+
        char(10) + "rpid" + " " + round_dec(RR_KP,2) + " " + round_dec(RR_KI,2) + " " + round_dec(RR_KD,2) +
        char(10) + "rmax" + " " + round_dec(RAD2DEG*rrate_max,1) +
        char(10) + "rask" + " " + round_dec(RAD2DEG*rratePD:SETPOINT,1) +
        char(10) + "ract" + " " + round_dec(RAD2DEG*roll_rate,1) +
        char(10) + "rerr" + " " + round_dec(RAD2DEG*rratePD:ERROR,1).
    }

    if ( false) { // yaw debug
    set hud_str to hud_str+
        char(10) + "ypid" + " " + round_dec(YR_KP,2) + " " + round_dec(YR_KI,2) + " " + round_dec(YR_KD,2) +
        char(10) + "ymax" + " " + round_dec(RAD2DEG*yrate_max,1) +
        char(10) + "yask" + " " + round_dec(RAD2DEG*yratePID:SETPOINT,1) +
        char(10) + "yact" + " " + round_dec(RAD2DEG*yaw_rate,1) +
        char(10) + "yerr" + " " + round_dec(RAD2DEG*yratePID:ERROR,1).
    }

    if ( false) { // q debug
    set hud_str to hud_str+
        char(10) + "q " + round_dec(ship:DYNAMICPRESSURE,7) +
        char(10) + "LF2G " + round_dec(LF2G,3) +
        char(10) + "WA " + round_dec(WING_AREA,1).
    }

    return hud_str.
}
