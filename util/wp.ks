
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED
// UTIL_SHBUS_RX_ENABLED

// a waypoint, (WP) is now a dictionary that can contain complete or limited
// information about where to go. It follows a few basic rules
//
// types: act, srf, snv, tar
// act (action group):
//  action basically does toggles an action group
// srf (surface):
//  atmosphere surface location has an SOI body and is meant to be
//  used inside an atmosphere, positions and everything are relative to surface
// snv (space nav):
//  incorporates the KOS maneuver queue (need to figure this out)
// tar (target):
//  works in a frame centered at a target vessel or docking port. Orientation
//  is ship:raw, but math shouldn't rely on

GLOBAL UTIL_WP_ENABLED IS true.

local PARAM is readJson("1:/param.json")["AP_NAV"].

// glimits
local ROT_GNOM_VERT is (choose PARAM["ROT_GNOM_VERT"] if PARAM:haskey("ROT_GNOM_VERT") else 0).
local ROT_GNOM_LAT is (choose PARAM["ROT_GNOM_LAT"] if PARAM:haskey("ROT_GNOM_LAT") else 0).
local ROT_GNOM_LONG is (choose PARAM["ROT_GNOM_LONG"] if PARAM:haskey("ROT_GNOM_LONG") else 0).

IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED IS false.}

local wp_queue is LIST().
local cur_mode is "srf".

// wp_queue is LIST of WAYPOINTS
// WAYPOINT is LIST containing [lat, long, h, vel]
// IF vel is zero, vel can be set by us


// TX SECTION

// many commands are mostly permutations of these
// five messages

// this function will be used by shbus_tx
// another function used by shbus_rx will fill in missing info
local function construct_incomplete_waypoint {
    parameter wp_args. // has to be a list of numbers
    parameter wp_mode is "srf".

    local wp is lexicon("mode", wp_mode).

    if wp_args:length = 1 {
        set wp["mode"] to "act". // if one arg, set to action regardless
    }

    if wp["mode"] = "act" {
        if wp_args:length = 1 {
            set wp["do_action"] to wp_args[0].
            return wp.
        }
    } else if wp["mode"] = "srf" {
        local L is wp_args:length.
        if L >= 2 {
            set wp["alt"] to wp_args[0].
            set wp["vel"] to wp_args[1].
        }
        if L = 3 {
            set wp["roll"] to wp_args[2].
            return wp.
        } else if L >= 4 {
            set wp["lat"] to wp_args[2].
            set wp["lng"] to wp_args[3].
        }

        if L = 4 {
            return wp.
        } else if L >= 6 {
            set wp["elev"] to wp_args[4].
            set wp["head"] to wp_args[5].
        }

        if L = 6 {
            return wp.
        } else if L >= 7 {
            set wp["nomg"] to wp_args[6].
        }

        if L = 7 {
            return wp.
        }
    } else if wp["mode"] = "snv" {
        // not implemented yet, setting invalid action
        set wp["mode"] to "act".
        set wp["do_action"] to -99.
        return wp.
    } else if wp["mode"] = "tar" {
        // not implemented yet
        set wp["mode"] to "act".
        set wp["do_action"] to -99.
        return wp.
    }
    print "received invalid waypoint data".
    set wp["mode"] to "inv".
    return wp.
}

local function overwrite_waypoint {
    parameter index.
    parameter wp_lex.
    if not (wp_lex["mode"] = "inv") {
        util_shbus_tx_msg("OWR_WP", list(index,wp_lex)).
    }
}
local function insert_waypoint {
    parameter index.
    parameter wp_lex.
    if not (wp_lex["mode"] = "inv") {
        util_shbus_tx_msg("INS_WP", list(index,wp_lex)).
    } else {
        print "invalid".
    }
}
local function remove_waypoint {
    parameter remindex.
    util_shbus_tx_msg("REM_WP", list(remindex)).
}
local function waypoints_print {
    util_shbus_tx_msg("WP_PRINT").
}
local function waypoints_purge {
    util_shbus_tx_msg("WP_PURGE").
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
        "wpmd mode   mode is act, srf, snv, tar",
        "wpd         delete first wp",
        "wpf(WP)     add wp to first ",
        "wpa(WP)     add wp to last ",
        "wpu(WP)     first wp write",
        "wpn(WP)     second wp write",
        "wpw(WP)     nav target wp",
        "wpt(WP)     vessel target wp",
        "wpk(alt,vel) go home",
        "wpl(distance,vel,GSlope) landing",
        "wpto(distance)  takeoff",
        "  WP = AGX (regardless of set mode)",
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
        list(start_alt, 350,
                lat+RAD2DEG*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*takeoff_distance/KERBIN:radius*sin(start_head)),
        list(start_alt+25, 350,
                lat+RAD2DEG*5/2*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5/2*takeoff_distance/KERBIN:radius*sin(start_head)),
        list(-2),
        list(start_alt+50, 350,
                lat+RAD2DEG*5*takeoff_distance/KERBIN:radius*cos(start_head),
                lng+RAD2DEG*5*takeoff_distance/KERBIN:radius*sin(start_head))
        ).
    return takeoff_sequence_WP.
}

local function generate_landing_seq {
    parameter distance.
    parameter speed.
    parameter GSlope.

    local lat_stp is -0.0493672258730508.
    local lng_stp is -74.6115615766677.
    local alt_td is 70.5.
    local runway_angle is 90.4.

    local stop_dist is 1000.
    local grdf is 10. // fraction of distance when to gear
    local flare_g is 0.1.
    local flare_radius is speed^2/flare_g/g0.
    set GSlope to abs(GSlope).

    local flare_long is flare_radius*sin(GSlope).
    local flare_h is flare_radius*(1-cos(GSlope)).

    local p5 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance)/ship:body:radius*RAD2DEG).
    local p4 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/2)/ship:body:radius*RAD2DEG).
    local pgr is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/grdf)/ship:body:radius*RAD2DEG).
    local p2f is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long)/ship:body:radius*RAD2DEG).
    local p1td is haversine_latlng(lat_stp,lng_stp,runway_angle+180,stop_dist/ship:body:radius*RAD2DEG).
    // local p1stp is haversine_latlng(lat_stp,lng_stp,0, 0).

    local landing_sequence is LIST(
    list(alt_td + flare_h +distance*tan(GSlope), speed, p5[0], p5[1], -GSlope,runway_angle),
    list(alt_td + flare_h +distance*tan(GSlope)/2, speed, p4[0], p4[1],-GSlope,runway_angle),
    list(alt_td + flare_h +distance*tan(GSlope)/grdf, speed, pgr[0], pgr[1],-GSlope,runway_angle),
    list(-2),
    list(alt_td + flare_h, speed, p2f[0], p2f[1], -GSlope,runway_angle),
    list(alt_td, speed-10,    p1td[0], p1td[1], -0.15,runway_angle,flare_g),
    list(alt_td-1.5, -1, lat_stp, lng_stp, -0.15,runway_angle,flare_g),
    list(-1)). // brakes

    return landing_sequence.
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_wp_parse_command {
    parameter commtext.
    local args is list().

    // don't even try if it's not a wp command
    if commtext:STARTSWITH("wp") {
        set args to util_shbus_tx_raw_input_to_args(commtext).
        if not (args = -1) and args:length = 0 {
            print "wp args expected but empty".
            return true.
        }
    } else {
        return false.
    }

    IF commtext:STARTSWITH("wpo(") {
        overwrite_waypoint(-args[0]-1,
            construct_incomplete_waypoint(args:SUBLIST(1,args:length-1), cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpi(") {
        insert_waypoint(-args[0]-2,
            construct_incomplete_waypoint(args:SUBLIST(1,args:length-1), cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpr(") {
        remove_waypoint(-args[0]-1).
    } ELSE IF commtext:STARTSWITH("wpqp"){
        waypoints_print().
    } ELSE IF commtext:STARTSWITH("wpqd"){
        waypoints_purge().
    } ELSE IF commtext:STARTSWITH("wpmd"){
        if (args = "act") or (args = "srf") or (args = "snv") or (args = "tar"){
            set cur_mode to args.
        } else {
            print "wp mode " + args + " not supported".
        }
    } ELSE IF commtext:STARTSWITH("wpd") { 
        remove_waypoint(0).
    } ELSE IF commtext:STARTSWITH("wpf(") { 
        insert_waypoint(0,
            construct_incomplete_waypoint(args, cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpa(") { 
        insert_waypoint(-1,
            construct_incomplete_waypoint(args, cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpu(") {
        overwrite_waypoint(0,
            construct_incomplete_waypoint(args, cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpn(") {
        overwrite_waypoint(1,
            construct_incomplete_waypoint(args, cur_mode) ).
    } ELSE IF commtext:STARTSWITH("wpw(") and args:length = 2  {
        FOR WP_TAR IN ALLWAYPOINTS() {
            IF (WP_TAR:ISSELECTED) {
                PRINT "Found navigation waypoint".
                insert_waypoint(-1,
                construct_incomplete_waypoint(list(args[0],args[1],WP_TAR:GEOPOSITION:LAT,
                    WP_TAR:GEOPOSITION:LNG), cur_mode) ).
                return true.
            }
        }
        PRINT "Could not find navigation waypoint".
    } ELSE IF commtext:STARTSWITH("wpt(") and args:length = 2 {
        IF HASTARGET {
            PRINT "Found Target.".
                insert_waypoint(-1,
                construct_incomplete_waypoint(list(args[0],args[1],TARGET:GEOPOSITION:LAT,
                    TARGET:GEOPOSITION:LNG), cur_mode) ).
            return true.
        } ELSE {
            PRINT "Could not find target".
        }
    } else if commtext:STARTSWITH("wpk(") and args:length = 2 {
        insert_waypoint(-1,
            construct_incomplete_waypoint(list(args[0],args[1],-0.048,
                -74.69), cur_mode) ).
    } else if commtext:STARTSWITH("wpl(") and args:length = 3 {
        for wp_seq_i in generate_landing_seq(args[0],args[1],args[2]) {
            insert_waypoint(-1,
                construct_incomplete_waypoint(wp_seq_i, "srf") ).
        }
    } else if commtext:STARTSWITH("wpto(") and args:length = 1 {
        waypoints_purge().
        for wp_seq_i in generate_takeoff_seq(args[0]) {
            insert_waypoint(-1,
                construct_incomplete_waypoint(wp_seq_i, "srf") ).
        }
    } ELSE {
        return false.
    }
    return true.
}

// TX SECTION END

// RX SECTION


local function fill_in_waypoint_data {
    parameter wp.
    if wp["mode"] = "act" {
        return wp.
    } else if wp["mode"] = "srf" {
        if wp:haskey("lat") and wp:haskey("lng") and
            ((not wp:haskey("elev")) or ( not wp:haskey("head"))){
                set wp["elev"] to 0.
                // set wp["head"] to latlng(wp["lat"],wp["lng"]):heading.
                set wp["head"] to haversine(wp["lat"],wp["lng"],
                            ship:geoposition:lat, ship:geoposition:lng)[0]-180.
            }
        if not wp:haskey("roll") {
            set wp["roll"] to 0.0.
        }
        if not wp:haskey("nomg") {
            set wp["nomg"] to max(0.05,max(ROT_GNOM_VERT,ROT_GNOM_LAT)).
        }
    } else if wp["mode"] = "snv" {

    } else if wp["mode"] = "tar" {

    }
    return wp.
}

local function waypoint_print_str {
    parameter WP.
    if WP["mode"] = "act" {
        return WP["mode"] + " " + WP["do_action"].
    } else if WP["mode"] = "srf" {
        if not WP:haskey("lat") {
            print "roll only WP will be depreciated".
            return WP["mode"] + " " + round(WP["alt"])
                        + " " + round(WP["vel"])
                        + " " + round(WP["roll"]).
        }
        return WP["mode"] + " " + round(WP["alt"])
                        + " " + round(WP["vel"])
                        + " (" + round_dec(wrap_angle_until(WP["lat"]),3)
                        + "," + round_dec(wrap_angle_until(WP["lng"]),3)
                        + ")(" + round_dec(wrap_angle_until(WP["elev"]),3)
                        + "," + round_dec(wrap_angle_until(WP["head"]),3)
                        + "," + round(WP["roll"])
                        + ") " + round_dec(WP["nomg"],2).
    }
    return "".
}

local function waypoint_do_leading_action {
    
    if wp_queue:length > 0 {
        if wp_queue[0]["mode"] = "act" {
            set action_code to wp_queue[0]["do_action"].
            waypoint_remove(0).
            print "doing action from waypoint".
            if action_code = 0 {
                if is_active_vessel() {
                    stage.
                } else {
                    print "cannot stage; not active".
                }
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
            } else if action_code = -99 {
                print "invalid wp except".
            } else {
                print "Could not parse action_str:".
                print wpcoords[0].
            }
            waypoint_do_leading_action().
        }
    }
}

local function waypoint_add {
    parameter pos.
    parameter new_wp.
    IF pos < 0 { SET pos TO pos+wp_queue:length+1.}
    wp_queue:insert(pos,new_wp).
}

local function waypoint_update {
    parameter pos.
    parameter new_wp.
    IF pos < 0 { SET pos TO pos+wp_queue:length.}
    IF wp_queue:length > pos {
        SET wp_queue[pos] TO new_wp.
    }
}

local function waypoint_remove {
    parameter pos.
    IF wp_queue:length = 0 {
        print "WPQ empty, returning".
        return.
    }
    IF pos < 0 { SET pos TO pos+wp_queue:length.}

    IF pos >= 0 and pos < wp_queue:length {
        wp_queue:REMOVE(pos).
    } else if pos = -1{
        wp_queue:REMOVE(wp_queue:length-1).
    } ELSE {
        PRINT "WP at pos " + pos +" does not exist".
    }
}

local function waypoint_queue_print {
    local wp_list_string is " WP (" +
        wp_queue:length + ")" + char(10).
    local i is wp_queue:ITERATOR.
    UNTIL NOT i:NEXT {
        set wp_list_string to wp_list_string+
            ""+ (wp_queue:length-i:index-1) +": " + waypoint_print_str(i:value) + char(10).
    }
    print wp_list_string.
    return wp_list_string.
}

local function waypoint_queue_purge {
    SET wp_queue TO LIST().
}

function util_wp_done {
    waypoint_do_leading_action().
    waypoint_remove(0).
}

function util_wp_queue_length {
    waypoint_do_leading_action().
    return wp_queue:length.
}

function util_wp_queue_last {
  return wp_queue[wp_queue:length-1].
}

function util_wp_queue_first {
    return wp_queue[0].
}

function util_wp_status_string {
    if wp_queue:length > 0 {
        return "WP" + (wp_queue:length-1) +" "+
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
        SET WP_itself TO data[1].
        waypoint_update(WP_index, fill_in_waypoint_data(WP_itself)).

    } else if opcode = "INS_WP"{
        SET WP_index TO data[0].
        SET WP_itself TO data[1].
        waypoint_add(WP_index, fill_in_waypoint_data(WP_itself)).

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
