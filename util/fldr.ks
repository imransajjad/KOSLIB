
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED
// UTIL_SHBUS_RX_ENABLED

GLOBAL UTIL_FLDR_ENABLED IS true.

local lock AG to AG5.
local PREV_AG is AG5.


local Ts is 0.04.
local Tdur is 5.0.
local Tdel is 0.

local logtag to "".
local filename is "".

local MAIN_ENGINES is get_engines(main_engine_name).

// TX SECTION

local function list_logs {
    if exists("logs"){
        cd("logs").
        LIST files.
        cd("..").
    }
}

local function send_logs {
    IF NOT has_connection_to_base() {
        PRINT "send_logs: no connection to KSC".
        RETURN.
    }
    if exists("logs"){
        cd("logs").
        LIST files IN FLIST.
        FOR F in FLIST {
            PRINT "send_logs: "+F.
            COPYPATH(F,"0:/logs/"+F).
            DELETEPATH(F).
        }
        cd("..").
    }
}

local function print_pos_info {
    print "time " + round_dec(TIME:SECONDS,3).
    print "dur " + round_dec(Tdur,3).
    print "dt  " + round_dec(Ts,3).
    print "lat  " + SHIP:GEOPOSITION:LAT.
    print "lng  " + SHIP:GEOPOSITION:LNG.
    print "h    " + SHIP:ALTITUDE.
    print "vs   " + SHIP:AIRSPEED.
    print "engine " + main_engine_name.
}

local function start_logging {
    LOCAL LOCK h TO SHIP:ALTITUDE.
    LOCAL LOCK m TO SHIP:MASS.

    LOCAL LOCK u0 TO SHIP:CONTROL:PILOTMAINTHROTTLE.
    LOCAL LOCK u1 TO SHIP:CONTROL:PITCH.
    LOCAL LOCK u2 TO SHIP:CONTROL:YAW.
    LOCAL LOCK u3 TO SHIP:CONTROL:ROLL.

    LOCAL LOCK vel TO SHIP:AIRSPEED.
    LOCAL LOCK pitch_rate TO (-SHIP:ANGULARVEL*SHIP:FACING:STARVECTOR).
    LOCAL LOCK yaw_rate TO (SHIP:ANGULARVEL*SHIP:FACING:TOPVECTOR).
    LOCAL LOCK roll_rate TO (-SHIP:ANGULARVEL*SHIP:FACING:FOREVECTOR).

    LOCAL LOCK DELTA_FACE_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
    LOCAL LOCK pitch TO DEG2RAD*(mod(DELTA_FACE_UP:pitch+90,180)-90).
    LOCAL LOCK yaw TO DEG2RAD*(360-DELTA_FACE_UP:yaw).
    LOCAL LOCK roll TO DEG2RAD*(180-DELTA_FACE_UP:roll).

    LOCAL LOCK DELTA_SRFPRO_UP TO R(90,0,0)*(-SHIP:UP)*(SHIP:SRFPROGRADE).
    LOCAL LOCK vel_pitch TO DEG2RAD*(mod(DELTA_SRFPRO_UP:pitch+90,180)-90).
    LOCAL LOCK vel_bear TO DEG2RAD*(360-DELTA_SRFPRO_UP:yaw).
    
    local get_thrust is {
        local total_thrust is 0.
        for e in MAIN_ENGINES {
            set total_thrust to total_thrust+e:MAXTHRUST.
        }
        return total_thrust.
    }.
    LOCAL LOCK thrust TO get_thrust().
    LOCAL LOCK thrust_vector TO (get_thrust()/SHIP:MASS)*SHIP:FACING:FOREVECTOR.

    LOCAL LOCK dynamic_pres TO SHIP:DYNAMICPRESSURE.


    LOCAL LOCK DELTA_ALPHA TO R(0,0,RAD2DEG*roll)*(-SHIP:SRFPROGRADE)*(SHIP:FACING).
    LOCAL LOCK alpha TO -DEG2RAD*(mod(DELTA_ALPHA:PITCH+180,360)-180).
    LOCAL LOCK beta TO  DEG2RAD*(mod(DELTA_ALPHA:YAW+180,360)-180).

    LOCAL LOCK VEL_FROM_FACE TO R(0,0,RAD2DEG*roll)*(-SHIP:SRFPROGRADE).

    LOCK Aup TO SHIP:MASS*(VEL_FROM_FACE*(SHIP:SENSORS:ACC-SHIP:SENSORS:GRAV-thrust_vector)):Y.
    LOCK Afore TO SHIP:MASS*(VEL_FROM_FACE*(SHIP:SENSORS:ACC-SHIP:SENSORS:GRAV-thrust_vector)):Z.
    LOCK Alat TO SHIP:MASS*(VEL_FROM_FACE*(SHIP:SENSORS:ACC-SHIP:SENSORS:GRAV-thrust_vector)):X.

    LOCAL LOCK lat TO SHIP:GEOPOSITION:LAT.
    LOCAL LOCK lng TO SHIP:GEOPOSITION:LNG.

    

    if has_connection_to_base(){
        set filename to "0:/logs/log_"+string_acro(SHIP:NAME)+"_"+TIME:CALENDAR:REPLACE(":","")+
            "_"+TIME:CLOCK:REPLACE(":","")+logtag+".csv".
    } else {
        set filename to "1:/logs/log_"+string_acro(SHIP:NAME)+"_"+TIME:CALENDAR:REPLACE(":","")+
            "_"+TIME:CLOCK:REPLACE(":","")+logtag+".csv".
    }

    SET filename TO filename:REPLACE(" ", "_").
    SET filename TO filename:REPLACE(",", "").
    PRINT "log writing to "+ filename.

    LOG "t,u0,u1,u2,u3,y0,y1,y2,y3,ft,p,y,r,vp,vh,afore,aup,alat,alpha,beta,h,m,q,lat,lng" to filename.
    LOG "" to filename.

    SET starttime to TIME:SECONDS.
    UNTIL TIME:SECONDS-starttime > Tdur {
        LOG TIME:SECONDS+","+u0+","+u1+","+u2+","+u3+
            ","+vel+","+pitch_rate+","+yaw_rate+","+roll_rate+
            ","+thrust+","+pitch+","+yaw+","+roll+
            ","+vel_pitch+","+vel_bear+
            ","+Afore+","+Aup+","+Alat+
            ","+alpha+","+beta+
            ","+h+","+m+","+dynamic_pres+
            ","+lat+","+lng
             to filename.
        WAIT Ts.
        if check_for_stop_logging() {
            break.
        }
    }

    PRINT "log written to "+ filename.
}

local function check_for_stop_logging {
     if AG <> PREV_AG {
        set PREV_AG to AG.
        return true.
    }
    return false.
}

function util_fldr_get_help_str {
    return list(
        " ",
        "UTIL_FLDR running on "+core:tag,
        "logtime(...)  set_log_duration(dur).",
        "logdt(...)  set_log_deltat(Ts).",
        "logtag [TAG].  set log tag.",
        "logengine [TAG]. set engine tag",
        "log.  start_logging().",
        "testlog.  start_test_log().",
        "listloginfo.  list_logs().",
        "sendlogs.  send_logs().",
        "logstp(...).  send_pulse_time(...).",
        "logsu0(...).  send_throttle_seq(...).",
        "logsu1(...).  send_pitch_seq(...).",
        "logsu2(...).  send_yaw_seq(...).",
        "logsu3(...).  send_roll_seq(...).",
        "logsupr.  print test sequences"
        ).
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_fldr_parse_command {
    PARAMETER commtext.

    // don't even try if it's not a log command
    if commtext:contains("log") {
        if commtext:contains("(") AND commtext:contains(")") {
            set args to util_shbus_raw_input_to_args(commtext).
            if args:length = 0 {
                print "fldr args empty".
                return true.
            }
        }
    } else {
        return false.
    }


    IF commtext:STARTSWITH("logtime(") {
        SET Tdur TO args[0].
    } ELSE IF commtext:STARTSWITH("logdt(") {
        SET Ts TO args[0].
    } ELSE IF commtext:STARTSWITH("logtag ") {
        set logtag to commtext:replace("logtag ", "_"):replace(".","").
    } ELSE IF commtext:STARTSWITH("logengine ") {
        set main_engine_name to commtext:replace("logengine ", ""):replace(".","").
        set MAIN_ENGINES to get_engines(main_engine_name).
    } ELSE IF commtext:STARTSWITH("log") {
        start_logging().
    } ELSE IF commtext:STARTSWITH("testlog") {
        util_shbus_tx_msg("FLDR_RUN_TEST").
        start_logging().
    } ELSE IF commtext:STARTSWITH("listloginfo") {
        print_pos_info().
        list_logs().
    } ELSE IF commtext:STARTSWITH("sendlogs") {
        send_logs().
    } ELSE IF commtext:STARTSWITH("logstp(") {
        util_shbus_tx_msg("FLDR_SET_SEQ_TP", args).
        SET Tdur TO listsum(args)+Tdel.

    } ELSE IF commtext:STARTSWITH("logsu0(") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U0", args).
        PRINT "Sent FLDR_SET_SEQ_U0 "+ args:join(" ").

    } ELSE IF commtext:STARTSWITH("logsu1(") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U1", args).
        PRINT "Sent FLDR_SET_SEQ_U1 "+ args:join(" ").

    } ELSE IF commtext:STARTSWITH("logsu2(") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U2", args).
        PRINT "Sent FLDR_SET_SEQ_U2 "+ args:join(" ").

    } ELSE IF commtext:STARTSWITH("logsu3(") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U3", args).
        PRINT "Sent SET_SEQ_U3 "+ args:join(" ").
    } ELSE IF commtext:STARTSWITH("logsupr") {
        util_shbus_tx_msg("FLDR_PRINT_TEST").
    } else {
        return false.
    }
    return true.
}

// TX SECTION END

// RX SECTION

SET U_seq TO LIST(LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0)).
SET PULSE_TIMES TO LIST(0,0,0,0,0).

function print_sequences {
    print "times".
    float_list_print(PULSE_TIMES,2).
    print "set sequences".
    for U in U_seq {
        float_list_print(U,2).
    }
}

// Run a test sequence
FUNCTION run_test_control {
    LOCAL u0_trim is SHIP:CONTROL:MAINTHROTTLE.
    LOCAL u1_trim is SHIP:CONTROL:PITCH.
    LOCAL u2_trim is SHIP:CONTROL:YAW.
    LOCAL u3_trim is SHIP:CONTROL:ROLL.

    IF NOT (U_seq[0]:LENGTH = U_seq[1]:LENGTH AND 
        U_seq[0]:LENGTH = U_seq[2]:LENGTH AND
        U_seq[0]:LENGTH = U_seq[3]:LENGTH AND
        U_seq[0]:LENGTH = PULSE_TIMES:LENGTH) {
        PRINT "lengths of control sequences not equal, aborting".
        RETURN.
    }
    LOCAL N is U_seq[0]:LENGTH.

    //UNLOCK SHIP:CONTROL:MAINTHROTTLE.

    SET INICES TO LIST().
    FOR i IN RANGE(0, N, 1) {
        SET SHIP:CONTROL:MAINTHROTTLE TO u0_trim + U_seq[0][i].
        SET SHIP:CONTROL:PITCH TO u1_trim + U_seq[1][i].
        SET SHIP:CONTROL:YAW TO u2_trim + U_seq[2][i].
        SET SHIP:CONTROL:ROLL TO u3_trim + U_seq[3][i].
        WAIT PULSE_TIMES[i].
    }
    PRINT "TEST COMPLETE, RETURNING CONTROL.".
}


// Returns true if message was decoded successfully
// Otherwise false
function util_fldr_decode_rx_msg {
    parameter received.

    set opcode to received:content[0].
    if not opcode:startswith("FLDR") {
        return.
    } else if received:content:length > 1 {
        set data to received:content[1].
    }

    IF opcode:startswith("FLDR_SET_SEQ_U") {
        SET Uindex TO opcode[14]:TONUMBER(-1).
        if Uindex >= 0 and Uindex < 4 {
            SET U_seq[Uindex] to data.
        }

    } ELSE IF opcode = "FLDR_SET_SEQ_TP" {
        SET PULSE_TIMES to data.

    } ELSE IF opcode = "FLDR_RUN_TEST" {
        run_test_control().
    } ELSE IF opcode = "FLDR_PRINT_TEST" {
        print_sequences().
    } else {
        print "could not decode fldr rx msg".
        return false.
    }
    return true.
}

// RX SECTION END

// log on action group
function util_fldr_log_on_ag {
    if AG <> PREV_AG {
        set PREV_AG to AG.
        start_logging().
    }
    wait Ts.
}