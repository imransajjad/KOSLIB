
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED (for tx commands)
// UTIL_SHBUS_RX_ENABLED (for rx commands)

global UTIL_FLDR_ENABLED is true.

local lock AG to AG5.


local Ts is 0.04.
local Tdur is 0.0.
local Tdel is 0.

local logtag to "".
local logdesc is "".

local fldr_evt_data is list(0,"").

list sensors in Slist.

local ACC_enabled is false.
local GRAV_enabled is false.

for i in Slist {
    if i:name = "sensorGravimeter"{
        set GRAV_enabled to true.
    }
    if i:name = "sensorAccelerometer"{
        set ACC_enabled to true.
    }
}


local PARAM is readJson("1:/param.json").
local MAIN_ENGINE_NAME is (choose PARAM["AP_AERO_ENGINES"]["MAIN_ENGINE_NAME"]
        if PARAM:haskey("AP_AERO_ENGINES") and
        PARAM["AP_AERO_ENGINES"]:haskey("MAIN_ENGINE_NAME") else "").

local MAIN_ENGINES is get_engines(MAIN_ENGINE_NAME).

// Locals for file logging naming etc
local FILENAME is "?". // a character that's invalid on every filesystem
local CORE_IS_LOGGING is false.
local SENDING_TO_BASE is false.
local starttime is 0.
local PREV_AG is AG.

local CORE_IS_TESTING is false.

// Local Locks for data recording

local lock h to ship:ALTITUDE.
local lock m to ship:MASS.

local lock u0 to ship:control:mainthrottle.
local lock u1 to ship:control:pitch.
local lock u2 to ship:control:yaw.
local lock u3 to ship:control:roll.

local lock vel to ship:AIRSPEED.
local lock pitch_rate to (-ship:ANGULARVEL*ship:FACING:STARVECTOR).
local lock yaw_rate to (ship:ANGULARVEL*ship:FACING:TOPVECTOR).
local lock roll_rate to (-ship:ANGULARVEL*ship:FACING:FOREVECTOR).

local lock DELTA_FACE_UP to R(90,0,0)*(-ship:UP)*(ship:FACING).
local lock pitch to DEG2RAD*(mod(DELTA_FACE_UP:pitch+90,180)-90).
local lock yaw to DEG2RAD*(360-DELTA_FACE_UP:yaw).
local lock roll to DEG2RAD*(180-DELTA_FACE_UP:roll).

local lock DELTA_SRFPRO_UP to R(90,0,0)*(-ship:UP)*(ship:SRFPROGRADE).
local lock vel_pitch to DEG2RAD*(mod(DELTA_SRFPRO_UP:pitch+90,180)-90).
local lock vel_bear to DEG2RAD*(360-DELTA_SRFPRO_UP:yaw).

local get_thrust is {
    local total_thrust is 0.
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:MAXTHRUST.
    }
    return total_thrust.
}.
local lock thrust to get_thrust().
local lock thrust_vector to (get_thrust()/ship:MASS)*ship:FACING:FOREVECTOR.

local lock dynamic_pres to ship:DYNAMICPRESSURE.


local lock ship_vel to (-SHIP:FACING)*ship:srfprograde.
local lock alpha to DEG2RAD*wrap_angle(ship_vel:pitch).
local lock beta to DEG2RAD*wrap_angle(-ship_vel:yaw).

local lock VEL_FROM_FACE to R(0,0,RAD2DEG*roll)*(-ship:SRFPROGRADE).

local Aup is 0.
local Afore is 0.
local Alat is 0.

local lock lat to ship:GEOPOSITION:LAT.
local lock lng to ship:GEOPOSITION:LNG.

// COMMON SECTION

local function get_last_log_filename {
    parameter send_to_home is HOMECONNECTION:ISCONNECTED.
    return (choose "0" if send_to_home else "1")+":/logs/lastlog".
}

local function list_logs {
    if exists("logs"){
        cd("logs").
        LIST files.
        cd("..").
    }
}

local function send_stashed_logs {
    if not HOMECONNECTION:ISCONNECTED {
        print "send_logs: no connection to KSC".
        return.
    }
    local basefilename is get_last_log_filename(false)+"stashed.csv".
    if exists(basefilename) {
        local i is 0.
        local lock fname to basefilename:replace("stashed.csv",""+i+"sent.csv"):replace("1:/","0:/").
        until not exists(fname) {
            set i to i+1.
        }
        copypath(basefilename,fname).
        deletepath(basefilename).
        print "stashed log sent to " + fname.
    } else {
        print basefilename+" does not exist".
    }
}

local function stash_last_log {
    local basefilename is get_last_log_filename(false).
    if exists(basefilename+".csv") {
        copypath(basefilename+".csv",basefilename+"stashed.csv").
        deletepath(basefilename+".csv").
        print "log stashed to " + basefilename+"stashed.csv".
    } else {
        print basefilename+".csv does not exist".
    }
}

local function get_info_string {
    set rstr to "time " + round_dec(time:seconds,3) +
    char(10) + "dur " + round_dec(Tdur,3) +
    char(10) + "dt  " + round_dec(Ts,3) +
    char(10) + "lat  " + ship:GEOPOSITION:LAT +
    char(10) + "lng  " + ship:GEOPOSITION:LNG +
    char(10) + "h    " + ship:ALTITUDE +
    char(10) + "vs   " + ship:AIRSPEED +
    char(10) + "engine " + MAIN_ENGINE_NAME +
    char(10) + "logtag " + logtag.

    local Filelist is -1.
    if exists("logs"){
        cd("logs").
        LIST files in Filelist.
        set rstr to rstr + char(10) + Filelist:join(char(10)).
        cd("..").
    }
    return rstr.
}

local time_logged is 0.
local function log_one_step {
    set FILENAME to get_last_log_filename() + ".csv".
    if SENDING_TO_BASE and not HOMECONNECTION:ISCONNECTED {
        set SENDING_TO_BASE to false.
        print "fldr connection lost".
    } else if not SENDING_TO_BASE and HOMECONNECTION:ISCONNECTED {
        set SENDING_TO_BASE to true.
        print "fldr connection regained".
        stash_last_log().
        send_stashed_logs().
    }
    if not SENDING_TO_BASE {
        // return.
    }

    log time:seconds+","+u0+","+u1+","+u2+","+u3+
        ","+vel+","+pitch_rate+","+yaw_rate+","+roll_rate+
        ","+thrust+","+pitch+","+yaw+","+roll+
        ","+vel_pitch+","+vel_bear+
        ","+Afore+","+Aup+","+Alat+
        ","+alpha+","+beta+
        ","+h+","+m+","+dynamic_pres+
        ","+lat+","+lng
        to FILENAME.
    // also check for messages while logging.
    // and record events sent by messages
    if not (fldr_evt_data[1] = "")
    {
        log "event, " + fldr_evt_data[0] + ", "+ fldr_evt_data[1]:replace(char(10), "\n") to FILENAME.
        set fldr_evt_data[1] to "".
    }
    if time:seconds - time_logged > 15 {
        print "logged " + round(time:seconds - time_logged) + " seconds".
        set time_logged to time:seconds.
    }
}

local function log_first_step {
    set FILENAME to get_last_log_filename() + ".csv".
    if exists(FILENAME) {
        deletepath(FILENAME).
        local i is 0.
        local lock fname to FILENAME:replace(".csv",""+i+"sent.csv").
        until not exists(fname){
            deletepath(fname).
            set i to i+1.
        }
    }

    local logdesc is "log_"+string_acro(ship:NAME)+"_"+TIME:CALENDAR:replace(":","")+
            "_"+TIME:CLOCK:replace(":","")+"_"+logtag.

    set logdesc to logdesc:replace(" ", "_"):replace(",", "").
    print "logging " + logdesc + " to " + FILENAME.

    log logdesc to FILENAME.
    log "t,u0,u1,u2,u3,y0,y1,y2,y3,ft,p,y,r,vp,vh,afore,aup,alat,alpha,beta,h,m,q,lat,lng" to FILENAME.
    log "" to FILENAME.

    set fldr_evt_data[1] to "".

    set starttime to time:seconds.

    if (GRAV_enabled and ACC_enabled) {
        print "Logging with ACC".
        lock Aup to ship:MASS*(VEL_FROM_FACE*(ship:SENSORS:ACC-ship:SENSORS:GRAV-thrust_vector)):Y.
        lock Afore to ship:MASS*(VEL_FROM_FACE*(ship:SENSORS:ACC-ship:SENSORS:GRAV-thrust_vector)):Z.
        lock Alat to ship:MASS*(VEL_FROM_FACE*(ship:SENSORS:ACC-ship:SENSORS:GRAV-thrust_vector)):X.
    } else {
        lock Aup to 0.
        lock Afore to 0.
        lock Alat to 0.
        print "No ACC data".
    }
}

local function check_for_stop_logging {
    return (AG <> PREV_AG) or
        (time:seconds-starttime > Tdur) and (Tdur > 0) or
        not CORE_IS_LOGGING.
}

// log on action group use without shbus
function util_fldr_log_on_ag {
    if AG <> PREV_AG {
        util_fldr_start_logging().
    }
    wait 0.
}

function util_fldr_start_logging {
    parameter LOG_IN_TRIGGER is false.
    
    if CORE_IS_LOGGING {
        // this function serves as its own inverse
        set CORE_IS_LOGGING to false.
        return.
    }
    set CORE_IS_LOGGING to true.
    set PREV_AG to AG.
    set SENDING_TO_BASE to HOMECONNECTION:ISCONNECTED.

    log_first_step(). // log the first step outside interrupt

    if LOG_IN_TRIGGER {
        local last_log_time is 0.
        when time:seconds - last_log_time > Ts then {
            if check_for_stop_logging() {
                print "log written to "+ FILENAME.
                set CORE_IS_LOGGING to false.
                return false.
            } else {
                log_one_step().
                set last_log_time to time:seconds.
                return true.
            }
        }
    } else {
        until check_for_stop_logging() {
            log_one_step().
            wait Ts.
        }
        print "log written to "+ FILENAME.
        set CORE_IS_LOGGING to false.
    }
}

// COMMON SECTION END

// TX SECTION

function util_fldr_get_help_str {
    return list(
        "UTIL_FLDR running on "+core:tag,
        "logtime(T)   total log time=T",
        "logdt(dt)    log interval =dt",
        "logtag TAG   set log tag on all",
        "log          start/stop logging on self",
        "remotelog    start/stop logging on hosts",
        "testlog      start test on hosts",
        "listloginfo  list logs",
        "remoteloginfo remote list logs",
        "sendlogs     send logs",
        "stashlog     save last log",
        "logstp(SEQ)  set pulse_time(SEQ)",
        "logsu0(SEQ)  set throttle_seq(SEQ)",
        "logsu1(SEQ)  set pitch_seq(SEQ)",
        "logsu2(SEQ)  set yaw_seq(SEQ)",
        "logsu3(SEQ)  set roll_seq(SEQ)",
        "logsupr.  print test sequences",
        "  SEQ = sequence of num",
        "This utility records flight data on the this core",
        "Logging can be stopped via the log command if logging with trigger (not default) or using the registered action group or if communication state changes"
        ).
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_fldr_parse_command {
    parameter commtext.
    parameter args is -1.

    // don't even try if it's not a log command
    if commtext:contains("log") {
        if not (args = -1) and args:length = 0 {
            print "fldr args expected but empty".
            return true.
        }
    } else {
        return false.
    }


    if commtext:startswith("logtime") {
        set Tdur to args[0].
        util_shbus_tx_msg("FLDR_SET_LOGTIME", list(Tdur)).
    } else if commtext:startswith("logdt") {
        set Ts to args[0].
        util_shbus_tx_msg("FLDR_SET_LOGTS", list(Ts)).
    } else if commtext:startswith("logtag") {
        if commtext:length > 7 {
            set logtag to commtext:replace("logtag",""):trim().
        } else {
            set logtag to "".
        }
        util_shbus_tx_msg("FLDR_SET_LOGTAG", list(logtag)).
    } else if commtext = "log" {
        util_fldr_start_logging().
    } else if commtext = "remotelog" {
        util_shbus_tx_msg("FLDR_TOGGLE_LOGGING").
    } else if commtext = "testlog" {
        util_shbus_tx_msg("FLDR_RUN_TEST").
    } else if commtext:startswith("listloginfo") {
        print get_info_string().
    } else if commtext:startswith("remoteloginfo") {
        util_shbus_tx_msg("FLDR_LOGINFO").
    } else if commtext:startswith("sendlogs") {
        send_stashed_logs().
    } else if commtext:startswith("stashlog") {
        stash_last_log().
    } else if commtext:startswith("logstp") {
        util_shbus_tx_msg("FLDR_SET_SEQ_TP", args).

    } else if commtext:startswith("logsu0") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U0", args).
        print "Sent FLDR_SET_SEQ_U0 "+ args:join(" ").

    } else if commtext:startswith("logsu1") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U1", args).
        print "Sent FLDR_SET_SEQ_U1 "+ args:join(" ").

    } else if commtext:startswith("logsu2") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U2", args).
        print "Sent FLDR_SET_SEQ_U2 "+ args:join(" ").

    } else if commtext:startswith("logsu3") {
        util_shbus_tx_msg("FLDR_SET_SEQ_U3", args).
        print "Sent SET_SEQ_U3 "+ args:join(" ").
    } else if commtext:startswith("logsupr") {
        util_shbus_tx_msg("FLDR_PRINT_TEST").
    } else {
        return false.
    }
    return true.
}

function util_fldr_send_event {
    parameter str_in.
    if CORE_IS_LOGGING {
        set fldr_evt_data to list(time:seconds, str_in).
    } else if (defined UTIL_SHBUS_ENABLED) and UTIL_SHBUS_ENABLED {
        util_shbus_tx_msg("FLDR_EVENT", list(time:seconds, str_in)).
    }
}

// TX SECTION END

// RX SECTION

// Test should not be run on TX side, so this is in the RX section
set U_seq to LIST(LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0)).
set PULSE_TIMES to LIST(0,0,0,0,0).

function print_sequences {
    local pstr is "times" + char(10).
    for t in PULSE_TIMES {
        set pstr to pstr + round_dec(t,2) + " ".
    }
    set pstr to pstr + char(10) + "set sequences" + char(10).
    for U in U_seq {
        for ux in U {
            set pstr to pstr + round_dec(ux,2) + " ".
        }
        set pstr to pstr + char(10).
    }
    print pstr.
    return pstr.
}

function util_fldr_run_test {
    if not CORE_IS_TESTING {
        return.
    }

    print "STARTING TEST, TAKING control.".

    local u0_trim is ship:control:mainthrottle.
    local u1_trim is ship:control:pitch.
    local u2_trim is ship:control:yaw.
    local u3_trim is ship:control:roll.

    // try and make sequence lengths equal to time
    for i in range(0,4) {
        if U_seq[i]:length > PULSE_TIMES:length {
            set U_seq[i]to U_seq[i]:sublist(0,PULSE_TIMES:length).
            // trim list if more
        }
        until U_seq[i]:length = PULSE_TIMES:length {
            U_seq[i]:add(0). // add zeros if less
        }
    }


    local N is U_seq[0]:length.

    for i in range(0, N, 1) {
        set ship:control:mainthrottle to u0_trim + U_seq[0][i].
        set ship:control:pitch to u1_trim + U_seq[1][i].
        set ship:control:yaw to u2_trim + U_seq[2][i].
        set ship:control:roll to u3_trim + U_seq[3][i].
        wait PULSE_TIMES[i].
        if AG <> PREV_AG  or not CORE_IS_TESTING {
            break.
        }
    }
    print "TEST COMPLETE, RETURNING control.".
    set CORE_IS_TESTING to false.
}


// Returns true if message was decoded successfully
// Otherwise false
function util_fldr_decode_rx_msg {
    parameter sender.
    parameter recipient.
    parameter opcode.
    parameter data.

    if not opcode:startswith("FLDR") {
        return.
    }

    if opcode:startswith("FLDR_SET_SEQ_U") {
        set Uindex to opcode[14]:tonumber(-1).
        if Uindex >= 0 and Uindex < 4 {
            set U_seq[Uindex] to data.
        }

    } else if opcode = "FLDR_SET_SEQ_TP" {
        set PULSE_TIMES to data.
    } else if opcode = "FLDR_RUN_TEST" {
        toggle CORE_IS_TESTING.
    } else if opcode = "FLDR_SET_LOGTAG" {
        set logtag to data[0].
    } else if opcode = "FLDR_SET_LOGTIME" {
        set Tdur to data[0].
    } else if opcode = "FLDR_SET_LOGTS" {
        set Ts to data[0].
    } else if opcode = "FLDR_LOGINFO" {
        local info_str is get_info_string().
        util_shbus_ack(info_str, sender).
        print info_str.
    } else if opcode = "FLDR_TOGGLE_LOGGING" {
        util_fldr_start_logging(true). // on rx side, test is always in trigger
    } else if opcode = "FLDR_PRINT_TEST" {
        util_shbus_ack(print_sequences(), sender).
    } else if opcode = "FLDR_EVENT" {
        set fldr_evt_data to data.
        print data[1].
    } else {
        util_shbus_ack("could not decode fldr rx msg", sender).
        print "could not decode fldr rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
