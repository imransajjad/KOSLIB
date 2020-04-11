
GLOBAL AP_FLCS_ROT_ENABLED IS true.

// USES AG6

local lock AG to AG6.

// FLCS PID STUFF

local lock pitch_rate to (-(SHIP:ANGULARVEL-SHIP:BODY:ANGULARVEL)*SHIP:FACING:STARVECTOR).
local lock yaw_rate to ((SHIP:ANGULARVEL-SHIP:BODY:ANGULARVEL)*SHIP:FACING:TOPVECTOR).
local lock roll_rate to (-(SHIP:ANGULARVEL-SHIP:BODY:ANGULARVEL)*SHIP:FACING:FOREVECTOR).


local lock LATOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:STARVECTOR.
local lock LONGOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:VECTOR.

local lock DELTA_ALPHA to R(0,0,roll)*(-SHIP:SRFPROGRADE)*(SHIP:FACING).
local lock alpha to -(mod(DELTA_ALPHA:PITCH+180,360)-180).


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

local MIN_FLCS_Q is 0.0003.
local MIN_PITCH_RATE is 2.5*DEG2RAD.

local MIN_SEA_Q is 1.0*(50/420)^2.
local CORNER_SEA_Q is 1.0*(AP_FLCS_CORNER_VELOCITY/420)^2.
local W_V_MAX is (AP_FLCS_ROT_GLIM_VERT*g0/AP_FLCS_CORNER_VELOCITY).
local W_L_MAX is (AP_FLCS_ROT_GLIM_LAT*g0/AP_FLCS_CORNER_VELOCITY).

local sc_geo_alpha is 0.32.
local WING_AREA is 0.

local lock GLimiter to ( prate_max+0.0001 + g0/vel*cos(vel_pitch)*cos(roll) >
    AP_FLCS_ROT_GLIM_VERT*g0/vel ).

local pratePID is PIDLOOP(
    AP_FLCS_ROT_PR_KP,
    AP_FLCS_ROT_PR_KI,
    AP_FLCS_ROT_PR_KD,
    -1.0,1.0).
local pitch_rate is 0.
if ( (defined AP_FLCS_RATE_SCHEDULE_ENABLED) and AP_FLCS_RATE_SCHEDULE_ENABLED)
{
    set WING_AREA to W_V_MAX/
            (CORNER_SEA_Q*cl_sched(AP_FLCS_CORNER_VELOCITY)*sc_geo_alpha)
            *(AP_FLCS_START_MASS*AP_FLCS_CORNER_VELOCITY).
    lock prate_max to 
        max(
            MIN_PITCH_RATE,
            min(
                WING_AREA*sc_geo_alpha*SHIP:DYNAMICPRESSURE*cl_sched(vel)/(ship:mass*vel),
                AP_FLCS_ROT_GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
} else {
    lock prate_max to max(
            MIN_PITCH_RATE,
            min(
                (vel/AP_FLCS_CORNER_VELOCITY)*W_V_MAX,
                AP_FLCS_ROT_GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
}

local yratePID is PIDLOOP(
    AP_FLCS_ROT_YR_KP,
    AP_FLCS_ROT_YR_KI,
    AP_FLCS_ROT_YR_KD,
    -1.0,1.0).
local lock yrate_max to MIN(
    W_L_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_SEA_Q),
    AP_FLCS_ROT_GLIM_LAT*g0/vel).

local rratePD is PIDLOOP(
    AP_FLCS_ROT_RR_KP,
    0,
    AP_FLCS_ROT_RR_KD,
    -1.0,1.0).

local rrateI is PIDLOOP(
    0,
    AP_FLCS_ROT_RR_KI,
    0,
    -0.05,0.05).

local lock rrate_max to sat(vel/AP_FLCS_CORNER_VELOCITY*AP_FLCS_MAX_ROLL, AP_FLCS_CORNER_VELOCITY/vel*AP_FLCS_MAX_ROLL).


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
        print "LF2G: " + round_dec(LF2G,2).
    }
    if prev_AG {
        set LF2G to LF2G/3.
    }
    set LF2G to LF2G/(AP_FLCS_PITCH_SPECIFIC_INERTIA*loadfactor*airflow_c_u)/kuniverse:timewarp:rate.

    set pratePID:KP to AP_FLCS_ROT_PR_KP*LF2G.
    set pratePID:KI to AP_FLCS_ROT_PR_KI*LF2G.
    set pratePID:KD to AP_FLCS_ROT_PR_KD*LF2G.

    set yratePID:KP to AP_FLCS_ROT_YR_KP*LF2G.
    set yratePID:KI to AP_FLCS_ROT_YR_KI*LF2G.
    set yratePID:KD to AP_FLCS_ROT_YR_KD*LF2G.
    
    set rratePD:KP to AP_FLCS_ROT_RR_KP*LF2G.
    set rrateI:KI to AP_FLCS_ROT_RR_KI*LF2G.
    set rratePD:KD to AP_FLCS_ROT_RR_KD*LF2G.
}


local Vslast is 0.0.
local prev_land is SHIP:STATUS.
local function display_land_stats {
    if not (SHIP:STATUS = prev_land) {
        if SHIP:STATUS = "LANDED" {
            local land_stats is "FLCS_ROT landed" + char(10) +
                "  pitch "+ round_dec(pitch,2) + char(10) +
                "  v/vs  "+ round_dec(vel,2) + "/"+round_dec(Vslast,2).
            if UTIL_HUD_ENABLED {
                util_hud_push_left("FLCS_ROT_LAND_STATS" , land_stats ).
            } else {
                print land_stats.
            }
        } else if SHIP:STATUS = "FLYING" {
            if UTIL_HUD_ENABLED {
                util_hud_pop_left("FLCS_ROT_LAND_STATS").
            }
            //print "FLCS_ROT flying gains".
        }
        set prev_land to SHIP:STATUS.
    }
    if ship:status = "FLYING" {
        SET Vslast TO SHIP:VERTICALSPEED.
    }
}


local FLCSon is true.
function ap_flcs_rot {
    PARAMETER u1. // pitch
    PARAMETER u2. // yaw
    PARAMETER u3. // roll in radians/sec
    parameter direct_mode is false.
    // in direct_mode, u1,u2,u3 are expected to be direct rate values
    // else they are stick inputs

    IF not SAS and ship:q > MIN_FLCS_Q {

        if (defined AP_FLCS_GAIN_SCHEDULE_ENABLED) and AP_FLCS_GAIN_SCHEDULE_ENABLED {
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

        if not FLCSon {
            set FLCSon to true.
        }
    } else {
        if FLCSon {
            set FLCSon to false.
            rrateI:RESET().
            yratePID:RESET().
            pratePID:RESET().
            SET SHIP:CONTROL:NEUTRALIZE to TRUE.
        }
    }
}

function ap_flcs_rot_maxrates {
    return list(RAD2DEG*prate_max,RAD2DEG*yrate_max,RAD2DEG*rrate_max).
}

function ap_flcs_rot_status_string {

    local hud_str is "".

    if (ship:q > MIN_FLCS_Q) {
        set hud_str to hud_str+( choose "GL " if GLimiter else "G ") +round_dec( vel*pitch_rate/g0 + 1.0*cos(vel_pitch)*cos(roll) ,1) + 
        char(10) + char(945) + " " + round_dec(alpha,1).    
    }
    


    if ( false) { // orbit info
        set hud_str to hud_str + ( choose char(10)+"t Ap "+round(eta:apoapsis)+"s" if eta:apoapsis > 25 and Vslast > 10 else "") +
        ( choose char(10)+"t Ap "+round(eta:apoapsis-ship:orbit:period)+"s" if (eta:apoapsis-ship:orbit:period) < -25 and Vslast < -10 else "").
    }

    if ( false) { // pitch debug
    set hud_str to hud_str+
        char(10) + "ppid" + " " + round_dec(AP_FLCS_ROT_PR_KP,2) + " " + round_dec(AP_FLCS_ROT_PR_KI,2) + " " + round_dec(AP_FLCS_ROT_PR_KD,2) +
        char(10) + "pmax" + " " + round_dec(RAD2DEG*prate_max,1) +
        char(10) + "pask" + " " + round_dec(RAD2DEG*pratePID:SETPOINT,1) +
        char(10) + "pact" + " " + round_dec(RAD2DEG*pitch_rate,1) +
        char(10) + "perr" + " " + round_dec(RAD2DEG*pratePID:ERROR,1) +
        char(10) + "q " + round_dec(ship:DYNAMICPRESSURE,7) +
        char(10) + "LF2G " + round_dec(LF2G,3) +
        char(10) + "WA " + round_dec(WING_AREA,1).
    }

    if ( false) { // roll debug
    set hud_str to hud_str+
        char(10) + "rpid" + " " + round_dec(AP_FLCS_ROT_RR_KP,2) + " " + round_dec(AP_FLCS_ROT_RR_KI,2) + " " + round_dec(AP_FLCS_ROT_RR_KD,2) +
        char(10) + "rmax" + " " + round_dec(RAD2DEG*rrate_max,1) +
        char(10) + "rask" + " " + round_dec(RAD2DEG*rratePD:SETPOINT,1) +
        char(10) + "ract" + " " + round_dec(RAD2DEG*roll_rate,1) +
        char(10) + "rerr" + " " + round_dec(RAD2DEG*rratePD:ERROR,1) +
        char(10) + "q " + round_dec(ship:DYNAMICPRESSURE,7) +
        char(10) + "LF2G " + round_dec(LF2G,3) +
        char(10) + "WA " + round_dec(WING_AREA,1).
    }

    return hud_str.
}
