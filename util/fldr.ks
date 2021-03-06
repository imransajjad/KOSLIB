
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED (for tx commands)
// UTIL_SHBUS_RX_ENABLED (for rx commands)

global UTIL_FLDR_ENABLED is true.

local Ts is 0.04.
local Tdur is 0.0.
local Tdel is 0.

local logtag to "".

local fldr_evt_data is queue(). // list(0,"").

// Locals for file logging naming etc
local FILENAME is "?". // a character that's invalid on every filesystem
local CORE_IS_LOGGING is false.
local SENDING_TO_BASE is false.
local CORE_IS_TESTING is false.
local last_sender is "".

// Local Locks for data recording

local lock locked_key_line to "t,u0,u1,u2,u3,u4,u5,u6,m,fx,fy,fz,q,lat,lng,h,svx,svy,svz,mu,opx,opy,opz,ovx,ovy,ovz,p,y,r,wp,wy,wr".

local lock locked_data_line to ""+time:seconds+
        ","+ship:control:mainthrottle+
        ","+ship:control:pitch+","+ship:control:yaw+","+ship:control:roll+
        ","+ship:control:starboard+","+ship:control:top+","+ship:control:fore+
        ","+ship:mass+
        ","+thrust:x+","+thrust:y+","+thrust:z+
        ","+ship:dynamicpressure+
        ","+ship:geoposition:lat+","+ship:geoposition:lng+","+ship:altitude+
        ","+velocity:surface:x+","+velocity:surface:y+","+velocity:surface:z+
        ","+ship:body:mu+
        ","+ship:body:position:x+","+ship:body:position:y+","+ship:body:position:z+
        ","+velocity:orbit:x+","+velocity:orbit:y+","+velocity:orbit:z+
        ","+ship:facing:pitch*DEG2RAD+","+ship:facing:yaw*DEG2RAD+","+ship:facing:roll*DEG2RAD+
        ","+ship:angularvel:x+","+ship:angularvel:y+","+ship:angularvel:z.

local thrust is V(0,0,0).
local get_thrust is {
    local total_thrust is V(0,0,0).
    list engines in MAIN_ENGINES.
    for e in MAIN_ENGINES {
        set total_thrust to total_thrust+e:thrust*e:facing:forevector.
    }
    set thrust to total_thrust.
}.

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

// Only one stashed log file can exist on a core while it does not have a
// connection to base. If connection is reestablished, this stashed log
// is sent immediately.

// On the base (archive), multiple files pertaining to the same log can exist.
// If a file called 0:/logs/lastlog[N]sent.csv exists on the archive, the
// stashed log is copied to 0:/logs/lastlog[N+1]send.csv
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
        print basefilename+" does not exist (send_stashed_logs)".
    }
}

local function stash_last_log {
    local basefilename is get_last_log_filename(false).
    if exists(basefilename+".csv") {
        copypath(basefilename+".csv",basefilename+"stashed.csv").
        deletepath(basefilename+".csv").
        print "log stashed to " + basefilename+"stashed.csv".
    } else {
        print basefilename+".csv does not exist (stash_last_log)".
    }
}
// The case of a crewed chip storing multiple logs through a single period of 
// connection loss is not handled.

local function get_info_string {
    set rstr to "time " + round_dec(time:seconds,3) +
    char(10) + "dur " + round_dec(Tdur,3) +
    char(10) + "dt  " + round_dec(Ts,3) +
    char(10) + "logtag " + logtag.

    get_thrust().

    local keys is locked_key_line:split(",").
    local data is locked_data_line:split(",").
    
    for i in range(0,keys:length) {
        set rstr to rstr + char(10) + "  " + keys[i] + ", " + data[i].
    }

    local Filelist is -1.
    if exists("logs"){
        cd("logs").
        LIST files in Filelist.
        set rstr to rstr + char(10) + Filelist:join(char(10)).
        cd("..").
    }
    return rstr.
}

local starttime is 0.
local time_logged_15 is 0.
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

    get_thrust().
    log locked_data_line to FILENAME.
    // also check for messages while logging.
    // and record events sent by messages
    until (fldr_evt_data:length = 0)
    {
        local popped is fldr_evt_data:pop.
        if popped:istype("list") and popped:length = 2 {
            log "event, " + popped[0] + ", "+ popped[1]:replace(char(10), "\n") to FILENAME.
        }
    }
    if time:seconds - time_logged_15 > 15 {
        print "logged " + round(time:seconds - time_logged_15) + " seconds".
        set time_logged_15 to time:seconds.
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

    local logdesc is "log-"+string_acro(ship:NAME)+"-"+TIME:CALENDAR:replace(":","")+
            "-"+TIME:CLOCK:replace(":","")+"-"+logtag.

    set logdesc to logdesc:replace(" ", "-"):replace(",", "").
    util_shbus_ack("logging " + logdesc + " to " + FILENAME, last_sender).
    print "started logging".

    log logdesc to FILENAME.
    log locked_key_line to FILENAME.
    log "" to FILENAME.

    fldr_evt_data:clear().

    set starttime to time:seconds.
    set time_logged_15 to time:seconds.
}

function util_fldr_start_logging {
    
    if CORE_IS_LOGGING {
        // this function serves as its own inverse
        set CORE_IS_LOGGING to false.
        return.
    }
    set CORE_IS_LOGGING to true.
    set SENDING_TO_BASE to HOMECONNECTION:ISCONNECTED.

    log_first_step(). // log the first step outside interrupt

    local last_log_time is 0.
    when time:seconds - last_log_time > Ts then {
        if ((time:seconds-starttime > Tdur) and (Tdur > 0)) or not CORE_IS_LOGGING {
            util_shbus_ack("log written to "+ FILENAME + char(10), last_sender).
            print "stopped logging".
            set CORE_IS_LOGGING to false.
            return false.
        } else {
            log_one_step().
            set last_log_time to time:seconds.
            return true.
        }
    }
}

// COMMON SECTION END

// TX SECTION

function util_fldr_get_help_str {
    return list(
        "UTIL_FLDR running on "+core:tag,
        "log time(T)    total log time=T",
        "log dt(dt)     log interval =dt",
        "log tag TAG    set log tag on hosts",
        "log start      start/stop logging on hosts",
        "log test       start test on hosts",
        "log info       list some log info",
        "log send       send logs",
        "log stash      save last log",
        "log stp(SEQ)   set pulse_time(SEQ)",
        "log su0(SEQ)   set throttle_seq(SEQ)",
        "log su1(SEQ)   set pitch_seq(SEQ)",
        "log su2(SEQ)   set yaw_seq(SEQ)",
        "log su3(SEQ)   set roll_seq(SEQ)",
        "log supr       print test sequences",
        "   SEQ = sequence of num",
        "log help       print help",
        "This utility records flight data",
        "Logging can be stopped via the log command start or if communication state changes"
        ).
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_fldr_parse_command {
    parameter commtext.
    parameter args is list().

    // don't even try if it's not a log command
    if commtext:startswith("log ") {
        set commtext to commtext:remove(0,4).
    } else {
        return false.
    }

    if commtext = "time" {
        if args:length = 1 and all_scalar(args) and args[0] >= 0 {
            set Tdur to args[0].
            util_shbus_tx_msg("FLDR_SET_LOGTIME", list(Tdur)).
        } else {
            print "expected one nonnegative scalar arg".
        }
    } else if commtext = "dt" {
        if args:length = 1 and all_scalar(args) and args[0] > 0 {
            set Ts to args[0].
            util_shbus_tx_msg("FLDR_SET_LOGTS", list(Ts)).
        } else {
            print "expected one positive scalar arg".
        }
    } else if commtext:startswith("tag") {
        if commtext:length > 4 {
            set logtag to commtext:replace("tag",""):trim().
        } else {
            set logtag to "".
        }
        util_shbus_tx_msg("FLDR_SET_LOGTAG", list(logtag)).
    } else if commtext = "start" {
        util_shbus_tx_msg("FLDR_TOGGLE_LOGGING").
    } else if commtext = "test" {
        util_shbus_tx_msg("FLDR_RUN_TEST").
    } else if commtext = "info" {
        util_shbus_tx_msg("FLDR_LOGINFO").
    } else if commtext = "send" {
        send_stashed_logs().
    } else if commtext = "stash"  {
        stash_last_log().
    } else if commtext = "stp" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_TP", args).
    } else if commtext = "su0" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U0", args).
    } else if commtext = "su1" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U1", args).
    } else if commtext = "su2" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U2", args).
    } else if commtext = "su3" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U3", args).
    } else if commtext = "su4" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U4", args).
    } else if commtext = "su5" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U5", args).
    } else if commtext = "su6" and all_scalar(args) {
        util_shbus_tx_msg("FLDR_SET_SEQ_U6", args).
    } else if commtext = "supr" {
        util_shbus_tx_msg("FLDR_PRINT_TEST").
    } else if commtext = "help" {
        util_term_parse_command("help FLDR").
    } else {
        return false.
    }
    return true.
}

function util_fldr_send_event {
    parameter str_in.
    if CORE_IS_LOGGING {
        fldr_evt_data:push(list(time:seconds, str_in)).
    }
}

// TX SECTION END

// RX SECTION

// Test should not be run on TX side, so this is in the RX section
set U_seq to LIST(LIST(0,0,0,0,0)
    ,LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0)
    ,LIST(0,0,0,0,0),LIST(0,0,0,0,0),LIST(0,0,0,0,0)).
set PULSE_TIMES to LIST(0,0,0,0,0).

function print_sequences {
    local pstr is "tp: " + round_dec_list(PULSE_TIMES,2):join(",") +
        char(10) + "u0: " + round_dec_list(U_seq[0],2):join(",") +
        char(10) + "u1: " + round_dec_list(U_seq[1],2):join(",") +
        char(10) + "u2: " + round_dec_list(U_seq[2],2):join(",") +
        char(10) + "u3: " + round_dec_list(U_seq[3],2):join(",") +
        char(10) + "u4: " + round_dec_list(U_seq[4],2):join(",") +
        char(10) + "u5: " + round_dec_list(U_seq[5],2):join(",") +
        char(10) + "u6: " + round_dec_list(U_seq[6],2):join(",").
    
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
    local u4_trim is ship:control:starboard.
    local u5_trim is ship:control:top.
    local u6_trim is ship:control:fore.

    // try and make sequence lengths equal to time
    for i in range(0,7) {
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
        set ship:control:starboard to u4_trim + U_seq[4][i].
        set ship:control:top to u5_trim + U_seq[5][i].
        set ship:control:fore to u6_trim + U_seq[6][i].
        wait PULSE_TIMES[i].
        if not CORE_IS_TESTING {
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
        if Uindex >= 0 and Uindex < 7 {
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
        set last_sender to sender.
        util_fldr_start_logging().
    } else if opcode = "FLDR_PRINT_TEST" {
        util_shbus_ack(print_sequences(), sender).
    } else {
        util_shbus_ack("could not decode fldr rx msg", sender).
        print "could not decode fldr rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
