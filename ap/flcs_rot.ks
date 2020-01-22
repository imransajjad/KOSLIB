
GLOBAL AP_FLCS_ROT_ENABLED IS true.

// USES AG6

local lock AG to AG6.

// FLCS PID STUFF

local lock pitch_rate to (-(SHIP:ANGULARVEL-KERBIN:ANGULARVEL)*SHIP:FACING:STARVECTOR).
local lock yaw_rate to ((SHIP:ANGULARVEL-KERBIN:ANGULARVEL)*SHIP:FACING:TOPVECTOR).
local lock roll_rate to (-(SHIP:ANGULARVEL-KERBIN:ANGULARVEL)*SHIP:FACING:FOREVECTOR).

local lock LOADFACTOR to SHIP:DYNAMICPRESSURE/SHIP:MASS.

local lock LATOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:STARVECTOR.
local lock LONGOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:VECTOR.


//RATE_DEG_MAX IS 45.
//GLIMIT_MAX IS 12.
//CORNER_VEL IS (GLIMIT_MAX*g0/(RATE_DEG_MAX*DEG2RAD)) ~ 145 m/s.

local CORNER_VEL is 145.

local CORNER_Q is (CORNER_VEL/345)^2.
local W_V_MAX is (AP_FLCS_ROT_GLIM_VERT*g0/CORNER_VEL).
local W_L_MAX is (AP_FLCS_ROT_GLIM_LAT*g0/CORNER_VEL).

local lock GLimiter to ( W_V_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_Q) >
    AP_FLCS_ROT_GLIM_VERT*g0/vel).

local pratePID is PIDLOOP(
    AP_FLCS_ROT_PR_KP,
    AP_FLCS_ROT_PR_KI,
    AP_FLCS_ROT_PR_KD,
    -1.0,1.0).
local lock prate_max to MIN(
    W_V_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_Q),
    AP_FLCS_ROT_GLIM_VERT*g0/vel).

local yratePID is PIDLOOP(
    AP_FLCS_ROT_YR_KP,
    AP_FLCS_ROT_YR_KI,
    AP_FLCS_ROT_YR_KD,
    -1.0,1.0).
local lock yrate_max to MIN(
    W_L_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_Q),
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

local lock rrate_max to MIN(
    4*PI*(vel/CORNER_VEL),
    4*PI).

local K_theta is 10.0.
local Kd_theta is 2.8.

local ROLL_I_ON is FALSE.

local prev_AG is AG.
local gain is 1.0.



local LF2G is 1.0.
local prev_status is SHIP:STATUS.
local Vslast is 0.0.
local function gain_schedule {
    //SET gain TO (1.0/(1.0))/(1.0+KUNIVERSE:TIMEWARP:WARP).
    if prev_AG <> AG {
        if AG {
            set LF2G to 1.0/3.
        } else{
            set LF2G to 1.0.
        }
        set prev_AG to AG.
        print "LF2G: " + round_dec(LF2G,2).
    }
    if not (SHIP:STATUS = prev_status) {
        if SHIP:STATUS = "LANDED" {
            SET pratePID:KI TO AP_FLCS_ROT_PR_KI_ALT.
            SET pratePID:KP TO AP_FLCS_ROT_PR_KP_ALT.

            local land_stats is "FLCS_ROT landed" + char(10) +
                "  pitch "+ round_dec(pitch,2) + char(10) +
                "  v/vs  "+ round_dec(vel,2) + "/"+round_dec(Vslast,2).
            if UTIL_HUD_ENABLED {
                util_hud_push_left("FLCS_ROT_LAND_STATS" , land_stats ).
            } else {
                print land_stats.
            }
        } else if SHIP:STATUS = "FLYING" {
            SET pratePID:KI TO AP_FLCS_ROT_PR_KI.
            SET pratePID:KP TO AP_FLCS_ROT_PR_KP.
            if UTIL_HUD_ENABLED {
                util_hud_pop_left("FLCS_ROT_LAND_STATS").
            }
            //print "FLCS_ROT flying gains".
        }
        set prev_status to SHIP:STATUS.
    }
    if ship:status = "FLYING" {
        SET Vslast TO SHIP:VERTICALSPEED.
    }
}


SET ROLL_I_ON TO TRUE.
local function check_for_cog_offset {
    IF (ABS(LATOFS) > 0.01) AND NOT ROLL_I_ON {
        SET ROLL_I_ON TO TRUE.
        SET rrateI:KI TO AP_FLCS_ROT_RR_KI.
    } ELSE IF NOT (ABS(LATOFS) > 0.01) AND ROLL_I_ON {
        SET ROLL_I_ON TO FALSE.
        SET rrateI:KI TO 0.0.
        rrateI:RESET().
    }
}


SET LAST_AGB TO FALSE.

local SASon is false.
function ap_flcs_rot {
    PARAMETER u1. // pitch
    PARAMETER u2. // yaw
    PARAMETER u3. // roll

    gain_schedule().

    IF not SAS {

        set pratePID:SETPOINT TO prate_max*u1.
        set yratePID:SETPOINT TO yrate_max*u2.
        set rratePD:SETPOINT TO rrate_max*u3.
        set rrateI:SETPOINT TO rrate_max*u3.

        set SHIP:CONTROL:YAW TO LF2G*yratePID:UPDATE(TIME:SECONDS, yaw_rate)
            +SHIP:CONTROL:YAWTRIM.

        local roll_pd is rratePD:UPDATE(TIME:SECONDS, roll_rate).
        local roll_i is 0.
        if (abs(u3) < 0.05) {
            set roll_i to rrateI:UPDATE(TIME:SECONDS, roll_rate).
        } else {
            rrateI:RESET().
        }

        set SHIP:CONTROL:ROLL TO LF2G*( roll_pd + roll_i ) +
            SHIP:CONTROL:ROLLTRIM.

        set SHIP:CONTROL:PITCH TO LF2G*pratePID:UPDATE(TIME:SECONDS, pitch_rate)+
            SHIP:CONTROL:PITCHTRIM.

        IF (BRAKES <> LAST_AGB) {
            set LAST_AGB to BRAKES.
            if not LAST_AGB {
                rrateI:RESET().
                yratePID:RESET().
                pratePID:RESET().
            }
        }
        if SASon {
            set SASon to false.
        }
    } else {
        if not SASon {
            set SASon to true.
            rrateI:RESET().
            yratePID:RESET().
            pratePID:RESET().
            SET SHIP:CONTROL:NEUTRALIZE to TRUE.
        }
    }
}

function ap_flcs_rot_status_string {
    LOCAL DELTA_ALPHA is R(0,0,roll)*(-SHIP:SRFPROGRADE)*(SHIP:FACING).
    LOCAL alpha is -(mod(DELTA_ALPHA:PITCH+180,360)-180).

    return ( choose "GL " if GLimiter else "G ") +round_dec( vel*pitch_rate/g0 ,1) + 
    char(10) + "a " + round_dec(alpha,1) +
    ( choose char(10)+"t Ap "+round(eta:apoapsis)+"s" if eta:apoapsis > 25 and Vslast > 10 else "").
}