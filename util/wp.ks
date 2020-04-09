
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED
// UTIL_SHBUS_RX_ENABLED

GLOBAL UTIL_WP_ENABLED IS true.

IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED IS false.}

// TX SECTION

// many commands are mostly permutations of these
// five messages

local function overwrite_waypoint {
    PARAMETER waypointCoords.
    set L to waypointCoords:length-1.
    if L = 1 or L = 3 or L = 4 or L = 6 {
        util_shbus_tx_msg("OWR_WP", waypointCoords).
        //PRINT "Sent OWR_WP "+ waypointCoords:join(" ").
    } else {
        PRINT "Waypoint length not 1, 3, 4 or 6, not sending".
    }
}
local function insert_waypoint {
    PARAMETER waypointCoords.
    set L to waypointCoords:length-1.
    if L = 1 or L = 3 or L = 4 or L = 6 {
        util_shbus_tx_msg("INS_WP", waypointCoords).
        //PRINT "Sent INS_WP "+ waypointCoords:join(" ").
    } else {
        PRINT "Waypoint length not 1, 3, 4 or 6, not sending".
    }
}
local function remove_waypoint {
    PARAMETER remindex.
    util_shbus_tx_msg("REM_WP", remindex).
    //PRINT "Sent REM_WP ".
}
local function waypoints_print {
    util_shbus_tx_msg("WP_PRINT").
    //PRINT "Sent WP_PRINT ".
}
local function waypoints_purge {
    util_shbus_tx_msg("WP_PURGE").
    //PRINT "Sent WP_PURGE ".
}

function util_wp_get_help_str {
    return LIST(
        " ",
        "UTIL_WP running on "+core:tag,
        "wpo(i,WP)   overwrite wp",
        "wpi(i,WP)   insert wp",
        "wpr(i)      remove wp ",
        "wpqp        print wp list",
        "wpqd        purge wp list",
        "wpf(WP)     add wp to first ",
        "wpa(WP)     add wp to last ",
        "wpu(WP)     first wp write",
        "wpn(WP)     second wp write",
        "wpw(WP)     nav target wp",
        "wpt(WP)     vessel target wp",
        "wpk(alt,vel) go home",
        "wpl(distance,vel,GSlope) landing",
        "wpto(distance)  takeoff",
        "  WP = AGX",
        "  WP = alt,vel,roll",
        "  WP = alt,vel,lat,lng",
        "  WP = alt,vel,lat,lng,pitch,bear"
        ).
}

local function generate_takeoff_seq {
    parameter takeoff_distance.
    
    local lat is ship:GEOPOSITION:LAT.
    local lng is ship:GEOPOSITION:LNG.
    local start_alt is ship:altitude.

    local start_head is (360- (R(90,0,0)*(-SHIP:UP)*(SHIP:FACING)):yaw).
    //print start_head.

    set takeoff_sequence_WP to LIST(
        list(-1, start_alt, 350,
                lat+RAD2DEG*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*takeoff_distance/KERBIN:radius*sin(start_head)),
        list(-1, start_alt+25, 350,
                lat+RAD2DEG*5/2*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5/2*takeoff_distance/KERBIN:radius*sin(start_head)),
        list(-1, -2),
        list(-1, start_alt+50, 350,
                lat+RAD2DEG*5*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5*takeoff_distance/KERBIN:radius*sin(start_head))
        ).
    return takeoff_sequence_WP.
}

local function generate_landing_seq {
    parameter distance.
    parameter speed.
    parameter GSlope.

    // -0.0487464272020686,-74.6999216423728 ideal touchdown point
    local lat_td is -0.0487464272020686.
    local longtd is -74.6999216423728.

    local flare_acc is (0.1*g0).
    local flare_radius is speed^2/flare_acc.
    set GSlope to abs(GSlope).

    local flare_long is flare_radius*sin(GSlope)/ship:body:radius*RAD2DEG.
    local flare_h is flare_radius*(1-cos(GSlope)).
    //print flare_radius.
    //print flare_long*DEG2RAD*ship:body:radius.
    //print flare_h.


    local long_ofs is distance/ship:body:radius*RAD2DEG.

    local landing_sequence is LIST(
    list(-1, 75 +distance*sin(GSlope), speed, -0.0485911247,-74.73766837-long_ofs,-GSlope,90.4),
    list(-1, 75 +distance*sin(GSlope)/2, speed, -0.0485911247,-74.73766837-long_ofs/2,-GSlope,90.4),
    list(-1, -2),
    list(-1, 70 + flare_h, speed, lat_td, longtd-flare_long,-GSlope,90.4),
    list(-1, 70, 0,    lat_td, longtd,-0.05,90.4),
    list(-1, 68,0,    -0.049359350,-74.625860287-0.01,-0.05,90.4),
    list(-1, -1)). // brakes

    return landing_sequence.
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_wp_parse_command {
    PARAMETER commtext.
    local args is list().

    // don't even try if it's not a wp command
    if commtext:STARTSWITH("wp") {
        if commtext:contains("(") AND commtext:contains(")") {
            set args to util_shbus_raw_input_to_args(commtext).
            if args:length = 0 {
                print "wp args empty".
                return true.
            }
        }
    } else {
        return false.
    }

    IF commtext:STARTSWITH("wpo(") {
        overwrite_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpi(") {
        insert_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpr(") {
        remove_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpqp"){
        waypoints_print().
    } ELSE IF commtext:STARTSWITH("wpqd"){
        waypoints_purge().

    } ELSE IF commtext:STARTSWITH("wpf(") { 
        args:INSERT(0,0).
        insert_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpa(") { 
        args:INSERT(0,-1).
        insert_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpu(") {
        args:INSERT(0,0).
        overwrite_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpn(") {
        args:INSERT(0,1).
        overwrite_waypoint(args).
    } ELSE IF commtext:STARTSWITH("wpw(") and args:length = 2  {
        FOR WP_TAR IN ALLWAYPOINTS() {
            IF (WP_TAR:ISSELECTED) {
                PRINT "Found navigation waypoint".
                insert_waypoint(LIST(-1,args[0],args[1],WP_TAR:GEOPOSITION:LAT,
                    WP_TAR:GEOPOSITION:LNG)).
                return true.
            }
        }
        PRINT "Could not find navigation waypoint".
    } ELSE IF commtext:STARTSWITH("wpt(") and args:length = 2 {
        IF HASTARGET {
            PRINT "Found Target.".
            insert_waypoint(LIST(-1,args[0],args[1] ,TARGET:GEOPOSITION:LAT,
                TARGET:GEOPOSITION:LNG)).
        } ELSE {
            PRINT "Could not find target".
        }
    } else if commtext:STARTSWITH("wpk(") and args:length = 2 {
        insert_waypoint(list(-1,args[0],args[1],-0.048,-74.69,0,90)).
    } else if commtext:STARTSWITH("wpl(") and args:length = 3 {
        for wp_seq_i in generate_landing_seq(args[0],args[1],args[2]) {
            insert_waypoint(wp_seq_i).
        }
    } else if commtext:STARTSWITH("wpto(") and args:length = 1 {
        waypoints_purge().
        for wp_seq_i in generate_takeoff_seq(args[0]) {
            insert_waypoint(wp_seq_i).
        }
    } ELSE {
        return false.
    }
    return true.
}

// TX SECTION END

// RX SECTION


SET WAYPOINT_QUEUE TO LIST().
// WAYPOINT_QUEUE is LIST of WAYPOINTS
// WAYPOINT is LIST containing [lat, long, h, vel]
// IF vel is zero, vel can be set by us



local function waypoint_print_str {
    PARAMETER WP.
    if WP:length = 1 {
        return WP[0].
    } else if WP:length = 3 {
        return "" + round_dec(WP[0],0) + ", " +
                    round_dec(WP[1],1)+ ", "+
                    round_dec(WP[2],2).
    } else if WP:length = 4 {
        return "" + round_dec(WP[0],0) + ", " +
                    round_dec(WP[1],1)+ ", "+
                    round_dec(WP[2],2)+ ", "+
                    round_dec(WP[3],2).
    } else if WP:length = 6 {
        return "" + round_dec(WP[0],0) + ", " +
                    round_dec(WP[1],1)+ ", "+
                    round_dec(WP[2],2)+ ", "+
                    round_dec(WP[3],2)+ ", "+
                    round_dec(WP[4],2)+ ", "+
                    round_dec(WP[5],2).
    }
}

local function waypoint_do_leading_action {
    
    if WAYPOINT_QUEUE:length > 0 {
        if WAYPOINT_QUEUE[0]:length = 1 {
            set action_code to WAYPOINT_QUEUE[0][0].
            waypoint_remove(0).
            print "doing action from waypoint".
            if action_code = 0 {
                stage.
            } else if action_code = 1 {
                toggle AG1.
            } else if action_code = 2 {
                toggle AG2.
            } else if action_code = 3 {
                toggle AG3.
            } else if action_code = 4 {
                toggle AG4.
            } else if action_code = 5 {
                toggle AG5.
            } else if action_code = 6 {
                toggle AG6.
            } else if action_code = 7 {
                toggle AG7.
            } else if action_code = 8 {
                toggle AG8.
            } else if action_code = 9 {
                toggle AG9.
            } else if action_code = -1 {
                toggle BRAKES.
            } else if action_code = -2 {
                toggle GEAR.
            } else if action_code = -3 {
                toggle RCS.
            } else if action_code = -4 {
                toggle SAS.
            } else if action_code = -5 {
                toggle LIGHTS.
            } else {
                print "Could not parse action_str:".
                print wpcoords[0].
            }
            waypoint_do_leading_action().
        }
    }
}

local function waypoint_add {
    PARAMETER POS.
    PARAMETER NEW_WP.
    IF POS < 0 { SET POS TO WAYPOINT_QUEUE:LENGTH.}
    WAYPOINT_QUEUE:INSERT(POS,NEW_WP).
}

local function waypoint_update {
    PARAMETER POS.
    PARAMETER NEW_WP.
    IF POS < 0 { SET POS TO POS+WAYPOINT_QUEUE:LENGTH.}
    IF WAYPOINT_QUEUE:LENGTH > POS {
        SET WAYPOINT_QUEUE[POS] TO NEW_WP.
    }
}

local function waypoint_remove {
    PARAMETER POS.
    IF WAYPOINT_QUEUE:LENGTH = 0 {
        print "WPQ empty, returning".
        return.
    }
    IF POS >= 0 and POS < WAYPOINT_QUEUE:LENGTH {
        WAYPOINT_QUEUE:REMOVE(POS).
    } else if POS = -1{
        WAYPOINT_QUEUE:REMOVE(WAYPOINT_QUEUE:LENGTH-1).
    } ELSE {
        PRINT "WP at pos " + POS +" does not exist".
    }
}

local function waypoint_queue_print {
    local wp_list_string is "WAYPOINT_QUEUE (" + 
        WAYPOINT_QUEUE:LENGTH + ")" + char(10).
    local i is WAYPOINT_QUEUE:ITERATOR.
    UNTIL NOT i:NEXT {
        set wp_list_string to wp_list_string+
            "WP"+ round(WAYPOINT_QUEUE:LENGTH-i:index-1) +": " + waypoint_print_str(i:value) + char(10).
    }
    print wp_list_string.
    return wp_list_string.
}

local function waypoint_queue_purge {
    SET WAYPOINT_QUEUE TO LIST().
}



function util_wp_done {
    waypoint_do_leading_action().
    waypoint_remove(0).
}

function util_wp_queue_length {
    waypoint_do_leading_action().
    return WAYPOINT_QUEUE:LENGTH.
}

function util_wp_queue_last {
  return WAYPOINT_QUEUE[WAYPOINT_QUEUE:LENGTH-1].
}

function util_wp_queue_first {
    return WAYPOINT_QUEUE[0].
}

function util_wp_status_string {
    if WAYPOINT_QUEUE:LENGTH > 0 {
        return "WP" + WAYPOINT_QUEUE:LENGTH +" "+ 
            (choose round_dec(min(9999,ap_nav_get_distance()/max(vel,0.0001)),0)+"s"
                if AP_NAV_ENABLED else "").
    } else {
        return "".
    }
}

// Returns true if message was decoded successfully
// Otherwise false
function util_wp_decode_rx_msg {
    parameter received.

    if not received:content[0]:contains("WP") {
        return false.
    }

    set opcode to received:content[0].
    if received:content:length > 0 {    
        set data to received:content[1].
    }

    if opcode = "OWR_WP"{
        SET WP_index TO data[0].
        SET WP_itself TO data:SUBLIST(1,data:length-1).
        waypoint_update(WP_index,WP_itself).

    } else if opcode = "INS_WP"{
        SET WP_index TO data[0].
        SET WP_itself TO data:SUBLIST(1,data:length-1).
        waypoint_add(WP_index,WP_itself).

    } else if opcode = "REM_WP"{
        SET WP_index TO data[0].
        waypoint_remove(WP_index).

    } else if opcode = "WP_PRINT"{
        util_shbus_rx_send_back_ack(waypoint_queue_print()).

    } else if opcode = "WP_PURGE"{
        waypoint_queue_purge().
        util_shbus_rx_send_back_ack("waypoint queue purged").
    } else {
        util_shbus_rx_send_back_ack("could not decode wp rx msg").
        print "could not decode wp rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
