
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
SET Vslast TO 0.0.
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
            print "FLCS_ROT landed".
            print "  pitch "+ round_dec(pitch,2).
            print "  v/vs  "+ round_dec(vel,2) + "/"+round_dec(Vslast,2).
        } else if SHIP:STATUS = "FLYING" {
            SET pratePID:KI TO AP_FLCS_ROT_PR_KI.
            SET pratePID:KP TO AP_FLCS_ROT_PR_KP.
            //print "FLCS_ROT flying gains".
        }
        set prev_status to SHIP:STATUS.
    }
    SET Vslast TO SHIP:VERTICALSPEED.
}


SET pitch_lock_armed TO false.
SET pitch_lock TO false.
SET Vlast TO 0.0.
SET Vslast TO 0.0.
local function check_for_pitch_lock {
    IF GEAR AND NOT pitch_lock_armed AND (SHIP:STATUS = "FLYING"){
        PRINT "check_for_pitch_lock: pitch_lock_armed".
        SET pitch_lock_armed TO true.
        if pilot_input_u0 > 0.6 {
            print "    throttle>0.6 will unlock pitch".
        }
    }
    IF SHIP:STATUS = "LANDED" AND pitch_lock_armed AND (NOT pitch_lock){
        SET pratePID:KI TO AP_FLCS_ROT_PR_KI_ALT.
        SET pratePID:KP TO AP_FLCS_ROT_PR_KP_ALT.
        
        PRINT "check_for_pitch_lock: pitch_locked".
        PRINT "    pitch         "+ round_dec(pitch,2).
        PRINT "    v/vs at land  "+ round_dec(Vlast,2) + "/"+round_dec(Vslast,2).
        SET pitch_lock TO true.
        SET pitch_lock_armed TO false.
  

    }
    IF pitch_lock AND 
    ((vel < 30) OR (ABS(pilot_input_u1) > 0.6) OR (pilot_input_u0 > 0.6)){
        SET pratePID:KI TO AP_FLCS_ROT_PR_KI.
        SET pratePID:KP TO AP_FLCS_ROT_PR_KP.

        SET pitch_set_point TO 0.
        SET pitch_lock TO false.
        PRINT "check_for_pitch_lock: pitch_unlocked".
    }
    IF NOT GEAR AND pitch_lock_armed {
        SET pitch_lock_armed TO false.
        PRINT "check_for_pitch_lock: pitch_lock_unarmed".
    }
    SET Vlast TO vel.
    SET Vslast TO SHIP:VERTICALSPEED.
    
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

local function roll_integrate_if_no_command {
    parameter roll_comm.

    if abs(roll_comm) > 0.10 {
        set rrateI:KI to 0.0.
    } else {
        set rrateI:KI to AP_FLCS_ROT_RR_KI.
    }
}

SET LAST_AGB TO FALSE.

local SASon is false.
function ap_flcs_rot {
    PARAMETER u1. // pitch
    PARAMETER u2. // yaw
    PARAMETER u3. // roll

    //check_for_sas().
    //check_for_pitch_lock().
    check_for_cog_offset().
    gain_schedule().
    //roll_integrate_if_no_command(u3).

    IF not SAS {

        set pratePID:SETPOINT TO prate_max*u1.
        set yratePID:SETPOINT TO yrate_max*u2.
        set rratePD:SETPOINT TO rrate_max*u3.
        set rrateI:SETPOINT TO rrate_max*u3.

        set SHIP:CONTROL:YAW TO LF2G*yratePID:UPDATE(TIME:SECONDS, yaw_rate)
            +SHIP:CONTROL:YAWTRIM.
        set SHIP:CONTROL:ROLL TO LF2G*( rratePD:UPDATE(TIME:SECONDS, roll_rate) +
            (choose rrateI:UPDATE(TIME:SECONDS, roll_rate) if (1.0+ABS(LATOFS) > 0.01) else 0) ) +
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
    return ""+round_dec( vel*pitch_rate/g0 ,1) + ( choose "GL" if GLimiter else "G") +
    char(10) + "q" + round_dec(ship:dynamicpressure,2).
}