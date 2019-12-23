
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
local pratePID is PIDLOOP(0.8,0.9,0.01, -1.0,1.0).
local lock prate_max to MIN(45*DEG2RAD*7.5*sqrt(LOADFACTOR), 12*g0/vel).
// at 100% pilot input, I should be at max at 12g


//local rratePID is PIDLOOP(0.1,0.01,0.001, -1.0,1.0).
local rratePID is PIDLOOP(0.1,0.011,0.001, -1.0,1.0).
local lock rrate_max to MIN(2*PI/145*vel,2*PI).

//local yratePID is PIDLOOP(1.5,0.0,0.00, -1.0,1.0).
local yratePID is PIDLOOP(1.5,0.0,0.00, -1.0,1.0).
local lock yrate_max to MIN(30*DEG2RAD*7.5*sqrt(LOADFACTOR), 2*g0/vel).

local K_theta is 10.0.
local Kd_theta is 2.8.

local pitch_local_point is 0.
local ROLL_I_ON is FALSE.

local prev_AG is AG.
local gain is 1.0.

local SASon is false.


FUNCTION gain_schedule {
    //SET gain TO (1.0/(1.0))/(1.0+KUNIVERSE:TIMEWARP:WARP).
    if prev_AG <> AG {
        if AG {
        set gain to 1.0/3.
        } else{
            set gain to 1.0.
        }
        set prev_AG to AG.
        print "LF2G: " + round_dec(gain,2).
    }
    return gain.
}

LOCK LF2G TO gain_schedule().


FUNCTION check_for_sas {
    IF SAS AND NOT SASon {
        SET SASon to true.
        SET PITCH_PID_I TO 0.0.
        SET PITCH_PID_D TO 0.0.
        SET ROLL_PID_I TO 0.0.
        SET ROLL_PID_D TO 0.0.
        rratePID:RESET().
        yratePID:RESET().
        pratePID:RESET().
        //plockPID:RESET().
        SET SHIP:CONTROL:NEUTRALIZE to TRUE.
    }
    IF NOT SAS AND SASon {
        SET SASon to false.
    }
}

SET pitch_lock_armed TO false.
SET pitch_lock TO false.
SET Vlast TO 0.0.
SET Vslast TO 0.0.
FUNCTION check_for_pitch_lock {
    IF GEAR AND NOT pitch_lock_armed AND (SHIP:STATUS = "FLYING"){
        PRINT "check_for_pitch_lock: pitch_lock_armed".
        SET pitch_lock_armed TO true.
        if pilot_input_u0 > 0.6 {
            print "    throttle>0.6 will unlock pitch".
        }
    }
    IF SHIP:STATUS = "LANDED" AND pitch_lock_armed AND (NOT pitch_lock){
        SET pitch_set_point TO pitch + SHIP:CONTROL:PITCH/K_theta.
        //SET pratePID:SETPOINT TO 0.
        //pratePID:RESET().
        PRINT "check_for_pitch_lock: pitch_locked".
        PRINT "    pitch lock sp "+ round_dec(pitch_set_point,2).
        PRINT "    v/vs at land  "+ round_dec(Vlast,2) + "/"+round_dec(Vslast,2).
        SET pitch_lock TO true.
        SET pitch_lock_armed TO false.
    }
    IF pitch_lock AND 
    ((vel < 30) OR (ABS(pilot_input_u1) > 0.6) OR (pilot_input_u0 > 0.6)){
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

SET LAST_AGB TO FALSE.
SET PITCH_LANDING_GAINS TO TRUE.
SET PITCH_NORMAL_KI TO pratePID:KI.
SET PITCH_NORMAL_KP TO pratePID:KP.

SET rratePID_KI TO rratePID:KI.
SET ROLL_I_ON TO TRUE.
FUNCTION check_for_cog_offset {
    IF (ABS(LATOFS) > 0.01) AND NOT ROLL_I_ON {
        SET ROLL_I_ON TO TRUE.
        SET rratePID:KI TO rratePID_KI.
    } ELSE IF NOT (ABS(LATOFS) > 0.01) AND ROLL_I_ON {
        SET ROLL_I_ON TO FALSE.
        SET rratePID:KI TO 0.0.
        rratePID:RESET().
    }
}

FUNCTION do_flcs {
    PARAMETER u1. // pitch
    PARAMETER u2. // yaw
    PARAMETER u3. // roll

    check_for_sas().
    check_for_pitch_lock().
    check_for_cog_offset().

    IF NOT SASon {
        SET yratePID:SETPOINT TO yrate_max*u2.
        SET SHIP:CONTROL:YAW TO LF2G*yratePID:UPDATE(TIME:SECONDS, yaw_rate)
            +SHIP:CONTROL:YAWTRIM.
        SET rratePID:SETPOINT TO rrate_max*u3.
        SET SHIP:CONTROL:ROLL TO LF2G*rratePID:UPDATE(TIME:SECONDS, roll_rate)
            +SHIP:CONTROL:ROLLTRIM.
        //IF pitch_lock {
        //  SET pitch_set_point to pitch_set_point + 0.1*prate_max*u1.
        //  SET SHIP:CONTROL:PITCH TO (pitch_set_point-pitch)*K_theta -
        //      pitch_rate*Kd_theta.

        //  SET pratePID:SETPOINT TO prate_max*deadzone(u1,0.1).
        //  pratePID:UPDATE(TIME:SECONDS, pitch_rate).
        //}
        //ELSE {
        //  SET pratePID:SETPOINT TO prate_max*u1.
        //  SET SHIP:CONTROL:PITCH TO LF2G*pratePID:UPDATE(TIME:SECONDS, pitch_rate)+
        //      SHIP:CONTROL:PITCHTRIM.
        //}
        IF PITCH_LANDING_GAINS AND NOT pitch_lock {
            SET PITCH_LANDING_GAINS TO FALSE.
            SET pratePID:KI TO PITCH_NORMAL_KI.
            SET pratePID:KP TO PITCH_NORMAL_KP.
        }
        ELSE IF NOT PITCH_LANDING_GAINS AND pitch_lock {
            SET PITCH_LANDING_GAINS TO TRUE.
            SET pratePID:KI TO K_theta.
            SET pratePID:KP TO Kd_theta.
        }
        SET pratePID:SETPOINT TO prate_max*u1.
        SET SHIP:CONTROL:PITCH TO LF2G*pratePID:UPDATE(TIME:SECONDS, pitch_rate)+
            SHIP:CONTROL:PITCHTRIM.

        IF (BRAKES <> LAST_AGB) {
            SET LAST_AGB TO BRAKES.
            IF NOT LAST_AGB {
                rratePID:RESET().
                yratePID:RESET().
                pratePID:RESET().
            }
        }
    }
}

FUNCTION do_flcs_pilot {
    do_flcs(pilot_input_u1, pilot_input_u2, pilot_input_u3).
}
