
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
        PRINT "Sent OWR_WP "+ waypointCoords:join(" ").
    } else {
        PRINT "Waypoint length not 1, 3, 4 or 6, not sending".
    }
}
local function insert_waypoint {
    PARAMETER waypointCoords.
    set L to waypointCoords:length-1.
    if L = 1 or L = 3 or L = 4 or L = 6 {
        util_shbus_tx_msg("INS_WP", waypointCoords).
        PRINT "Sent INS_WP "+ waypointCoords:join(" ").
    } else {
        PRINT "Waypoint length not 1, 3, 4 or 6, not sending".
    }
}
local function remove_waypoint {
    PARAMETER remindex.
    util_shbus_tx_msg("REM_WP", remindex).
    PRINT "Sent REM_WP ".
}
local function waypoints_print {
    util_shbus_tx_msg("WP_PRINT").
    PRINT "Sent WP_PRINT ".
}
local function waypoints_purge {
    util_shbus_tx_msg("WP_PURGE").
    PRINT "Sent WP_PURGE ".
}

function util_wp_get_help_str {
    return LIST(
        " ",
        "UTIL_WP running on "+core:tag,
        "wpo(index,#WP#).   overwrite wp.",
        "wpi(index,#WP#).   insert wp.",
        "wpr(index).        remove wp .",
        "wpqp.      print wp list.",
        "wpqd.      purge wp list.",
        "wpf(#WP#).  add wp to first .",
        "wpa(#WP#).  add wp to last .",
        "wpu(#WP#).  first wp overwrite.",
        "wpn(#WP#).  second wp overwrite.",
        "wpw(#WP#).  nav target wp.",
        "wpt(#WP#).  vessel target wp.",
        "wpk(#WP#). go home.",
        "wpto.       takeoff.",
        "#WP# = AGX",
        "#WP# = alt,vel",
        "#WP# = alt,vel,roll",
        "#WP# = alt,vel,lat,lng",
        "#WP# = alt,vel,lat,lng,pitch,bear"
        ).
}

local function generate_takeoff_seq {
    local lat is ship:GEOPOSITION:LAT.
    local lng is ship:GEOPOSITION:LNG.
    local start_alt is ship:altitude.

    local start_head is (360- (R(90,0,0)*(-SHIP:UP)*(SHIP:FACING)):yaw).
    print start_head.

    if not ( DEFINED UTIL_WP_takeoff_distance ) {
        set takeoff_sequence_WP to list().
        return.
    }

    set takeoff_sequence_WP to LIST(
        list(-1, start_alt, 350,
                lat+RAD2DEG*UTIL_WP_takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*UTIL_WP_takeoff_distance/KERBIN:radius*sin(start_head)),
        list(-1, start_alt+25, 350,
                lat+RAD2DEG*5/2*UTIL_WP_takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5/2*UTIL_WP_takeoff_distance/KERBIN:radius*sin(start_head)),
        list(-1, -2),
        list(-1, start_alt+50, 350,
                lat+RAD2DEG*5*UTIL_WP_takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5*UTIL_WP_takeoff_distance/KERBIN:radius*sin(start_head))
        ).
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_wp_parse_command {
    PARAMETER commtext.

    // don't even try if it's not a wp command
    if commtext:STARTSWITH("wp") {
        if commtext:contains("(") AND commtext:contains(").") {
            set args to util_shbus_raw_input_to_args(commtext).
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
    } ELSE IF commtext:STARTSWITH("wpqp."){
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
    } ELSE IF commtext:STARTSWITH("wpw(") {
        FOR WP_TAR IN ALLWAYPOINTS() {
            IF (WP_TAR:ISSELECTED) {
                PRINT "Found navigation waypoint".
                insert_waypoint(LIST(-1,args[0],args[1],WP_TAR:GEOPOSITION:LAT,
                    WP_TAR:GEOPOSITION:LNG)).
                RETURN.
            }
        }
        PRINT "Could not find navigation waypoint".
    } ELSE IF commtext:STARTSWITH("wpt(") {
        IF HASTARGET {
            PRINT "Found Target.".
            insert_waypoint(LIST(-1,args[0],args[1] ,TARGET:GEOPOSITION:LAT,
                TARGET:GEOPOSITION:LNG)).
        } ELSE {
            PRINT "Could not find target".
        }
    } else if commtext:STARTSWITH("wpk("){
        if ( DEFINED UTIL_WP_landing_sequence) {
            set UTIL_WP_landing_sequence[0][1] to args[0].
            set UTIL_WP_landing_sequence[0][2] to args[1].
            for wp_seq_i in UTIL_WP_landing_sequence {
                insert_waypoint(wp_seq_i).
            }
        } else {
            print "No landing sequence defined".
        }
    } else if commtext:STARTSWITH("wpto."){
        if ( DEFINED UTIL_WP_takeoff_distance) {
            generate_takeoff_seq().
            waypoints_purge().
            for wp_seq_i in takeoff_sequence_WP {
                insert_waypoint(wp_seq_i).
            }
        } else {
            print "No takeoff distance defined.".
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
    IF WAYPOINT_QUEUE:LENGTH > POS {
        WAYPOINT_QUEUE:REMOVE(POS).
    } ELSE {
        PRINT "WP at pos " + POS +" does not exist".
    }
}

local function waypoint_queue_print {
    PRINT "WAYPOINT_QUEUE (" + WAYPOINT_QUEUE:LENGTH + ")".
    SET i TO WAYPOINT_QUEUE:ITERATOR.
    UNTIL NOT i:NEXT {
        SET WP TO i:VALUE.
        PRINT "WP: " + waypoint_print_str(WP).
    }
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
        waypoint_queue_print().

    } else if opcode = "WP_PURGE"{
        waypoint_queue_purge().
    } else {
        print "could not decode wp rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
