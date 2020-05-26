
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

local PARAM is readJson("1:/param.json").

local USE_AP_NAV is PARAM:haskey("AP_NAV").

local NOM_NAV_G is 1.0.
local GCAS_ALTITUDE is 0.0.

if PARAM:haskey("AP_NAV") {
    set NOM_NAV_G to get_param(PARAM["AP_NAV"], "ROT_GNOM_VERT", NOM_NAV_G).
    set GCAS_ALTITUDE to get_param(PARAM["AP_NAV"], "GCAS_MARGIN", GCAS_ALTITUDE).
}

local wp_queue is LIST().
local cur_mode is "srf".

// wp_queue is LIST of WAYPOINTS
// WAYPOINT is LIST containing [lat, long, h, vel]
// if vel is zero, vel can be set by us


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
        if L >= 4 {
            set wp["lat"] to wp_args[2].
            set wp["lng"] to wp_args[3].
        }
        if L >= 6 {
            set wp["elev"] to wp_args[4].
            set wp["head"] to wp_args[5].
        }
        if L >= 7 {
            set wp["nomg"] to wp_args[6].
        }
        return wp.
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
        "  WP = alt,vel,lat,lng",
        "  WP = alt,vel,lat,lng,pitch,bear"
        ).
}

local function generate_takeoff_seq {
    parameter takeoff_distance.
    parameter heading.
    
    local lat is ship:geoposition:lat.
    local lng is ship:geoposition:lng.
    local start_alt is ship:altitude.

    //print start_head.

    local pullup_angle is 5.
    local pullup_radius is takeoff_distance/2.

    local p1 is haversine_latlng(lat,lng, heading,
        (takeoff_distance)/ship:body:radius*RAD2DEG).
    local pr is haversine_latlng(lat,lng, heading,
        (takeoff_distance+pullup_radius*sin(pullup_angle))
        /ship:body:radius*RAD2DEG).
    local pesc is haversine_latlng(lat,lng, heading,
        (takeoff_distance+pullup_radius*sin(pullup_angle)+ takeoff_distance*cos(pullup_angle))
        /ship:body:radius*RAD2DEG).

    set takeoff_sequence_WP to LIST(
        list(start_alt, 350, p1[0], p1[1]),
        list(start_alt+pullup_radius*(1-cos(pullup_angle)), 350, pr[0], pr[1],pullup_angle,heading),
        list(start_alt+pullup_radius*(1-cos(pullup_angle))+
            takeoff_distance*sin(pullup_angle), 350, pesc[0], pesc[1],pullup_angle,heading),
        list("g")
        ).
    return takeoff_sequence_WP.
}

local function generate_landing_seq {
    parameter distance.
    parameter speed.
    parameter GSlope.
    parameter runway_angle.

    local lat_stp is -0.0493672258730508.
    local lng_stp is -74.6115615766677.
    local alt_stp is latlng(lat_stp,lng_stp):terrainheight+3.0.

    local stop_dist is 1000.
    set GSlope to abs(GSlope).
    local LSlope is 0.15.

    local flare_radius is max(10*(0.857*speed)/((GSlope-LSlope)*DEG2RAD),
                (0.857*speed)^2/((NOM_NAV_G/16)*g0) ).
                    // at least 10 second flare or what navg allows
    local flare_g is (0.857*speed)^2/flare_radius/g0.

    local flare_long is flare_radius*(sin(GSlope) - sin(LSlope)).
    local flare_h is flare_radius*(cos(LSlope)-cos(GSlope)).

    local p5 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance)/ship:body:radius*RAD2DEG).
    local p4 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/2)/ship:body:radius*RAD2DEG).
    local p3 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/10)/ship:body:radius*RAD2DEG).
    local p2f is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long)/ship:body:radius*RAD2DEG).
    local p1td is haversine_latlng(lat_stp,lng_stp,runway_angle+180,stop_dist/ship:body:radius*RAD2DEG).
    // local p1stp is haversine_latlng(lat_stp,lng_stp,0, 0).

    local landing_sequence is LIST(
    list(alt_stp + flare_h +distance*tan(GSlope), 1.43*speed, p5[0], p5[1], -GSlope,runway_angle),
    list(alt_stp + flare_h +distance*tan(GSlope)/2, 1.17*speed, p4[0], p4[1],-GSlope,runway_angle),
    list(alt_stp + flare_h +distance*tan(GSlope)/10, 1.17*speed, p3[0], p3[1],-GSlope,runway_angle),
    list(alt_stp + flare_h, speed, p2f[0], p2f[1], -GSlope,runway_angle),
    list("g"),
    list(alt_stp , 0.857*speed,    p1td[0], p1td[1], -LSlope,runway_angle,flare_g),
    list(alt_stp-3.0, -1, lat_stp, lng_stp, -LSlope,runway_angle,flare_g),
    list("b")). // brakes

    if flare_h < GCAS_ALTITUDE {
        landing_sequence:remove(4).
        landing_sequence:insert(3, list("g")).
    }

    return landing_sequence.
}

// This function returns true if the command was parsed and Sent
// Otherwise it returns false.
function util_wp_parse_command {
    parameter commtext.
    parameter args is -1.

    // don't even try if it's not a wp command
    if commtext:startswith("wp") {
        if not (args = -1) and args:length = 0 {
            print "wp args expected but empty".
            return true.
        }
    } else {
        return false.
    }
    local brackets is commtext:contains("(") and commtext:contains(")").

    if commtext:startswith("wpo") {
        overwrite_waypoint(-args[0]-1,
            construct_incomplete_waypoint(args:sublist(1,args:length-1), cur_mode) ).
    } else if commtext:startswith("wpi") {
        insert_waypoint(-args[0]-2,
            construct_incomplete_waypoint(args:sublist(1,args:length-1), cur_mode) ).
    } else if commtext:startswith("wpr") {
        remove_waypoint(-args[0]-1).
    } else if commtext = "wpqp" {
        waypoints_print().
    } else if commtext = "wpqd" {
        waypoints_purge().
    } else if commtext = "wpmd" {
        if (args = "act") or (args = "srf") or (args = "snv") or (args = "tar"){
            set cur_mode to args.
        } else {
            print "wp mode " + args + " not supported".
        }
    } else if commtext = "wpd" { 
        remove_waypoint(0).
    } else if commtext:startswith("wpf") { 
        insert_waypoint(0,
            construct_incomplete_waypoint(args, cur_mode) ).
    } else if commtext:startswith("wpa") { 
        insert_waypoint(-1,
            construct_incomplete_waypoint(args, cur_mode) ).
    } else if commtext:startswith("wpu") {
        overwrite_waypoint(0,
            construct_incomplete_waypoint(args, cur_mode) ).
    } else if commtext:startswith("wpn") {
        overwrite_waypoint(1,
            construct_incomplete_waypoint(args, cur_mode) ).
    } else if commtext:startswith("wpw") and args:length = 2  {
        if is_active_vessel() {
            FOR WP_TAR IN ALLWAYPOINTS() {
                if (WP_TAR:ISSELECTED) {
                    print "Found navigation waypoint".
                    insert_waypoint(-1,
                    construct_incomplete_waypoint(list(args[0],args[1],WP_TAR:GEOPOSITION:LAT,
                        WP_TAR:GEOPOSITION:LNG), cur_mode) ).
                    return true.
                }
            }
        }
        print "Could not find navigation waypoint".
    } else if commtext:startswith("wpt(") and args:length = 2 {
        if is_active_vessel() and HASTARGET {
            print "Found Target.".
                insert_waypoint(-1,
                construct_incomplete_waypoint(list(args[0],args[1],TARGET:GEOPOSITION:LAT,
                    TARGET:GEOPOSITION:LNG), cur_mode) ).
            return true.
        } else {
            print "Could not find target".
        }
    } else if commtext:startswith("wpk(") and args:length = 2 {
        insert_waypoint(-1,
            construct_incomplete_waypoint(list(args[0],args[1],-0.048,
                -74.69), cur_mode) ).
    } else if commtext:startswith("wpl(") and 
    (args:length = 3 or args:length = 4) {
        if args:length = 3 { args:insert(3,90.4 +
                (choose 180 if ship:geoposition:lng > -74.69 else 0) ). }
        for wp_seq_i in generate_landing_seq(args[0],args[1],args[2],args[3]) {
            insert_waypoint(-1,
                construct_incomplete_waypoint(wp_seq_i, "srf") ).
        }
    } else if commtext:startswith("wpto(") and (args:length = 1 or args:length = 2) {
        waypoints_purge().
        util_shbus_tx_msg("WP_TAKEOFF", args). // special command for take off
    } else if commtext:startswith("wptest") {
                insert_waypoint(-1,
            construct_incomplete_waypoint(list(3000,230,0.5,
                -74,0,270), "srf") ).
    } else {
        return false.
    }
    return true.
}

// TX SECTION END

// RX SECTION


local function fill_in_waypoint_data {
    parameter wp.
    set wp["complete"] to true.
    if wp["mode"] = "act" {
        if not wp:haskey("do_action") {
            set wp["do_action"] to -99.
        }
        return wp.
    } else if wp["mode"] = "srf" {
        if not wp:haskey("lat") or not wp:haskey("lng") {
            local lat_lng_opp is haversine_latlng(
                            ship:geoposition:lat, ship:geoposition:lng,
                                vel_bear, 175).
            set wp["lat"] to lat_lng_opp[0].
            set wp["lng"] to lat_lng_opp[1].
        }
        if (not wp:haskey("elev")) or ( not wp:haskey("head")) {
            set wp["elev"] to 0.
            // set wp["head"] to latlng(wp["lat"],wp["lng"]):heading.
            set wp["head"] to haversine(wp["lat"],wp["lng"],
                        ship:geoposition:lat, ship:geoposition:lng)[0]-180.
        }
        if not wp:haskey("soi_name") {
            set wp["soi_name"] to ship:body:name.
        }        
        if not wp:haskey("roll") {
            set wp["roll"] to 0.0.
        }
        if not wp:haskey("nomg") {
            set wp["nomg"] to max(0.05,NOM_NAV_G).
        }
        return wp.
    } else if wp["mode"] = "snv" {
        return wp.
    } else if wp["mode"] = "tar" {
        return wp.
    }
}

local function waypoint_print_str {
    parameter WP.
    if WP["mode"] = "act" {
        return WP["mode"] + " " + WP["do_action"].
    } else if WP["mode"] = "srf" {
        return WP["mode"] + " " + round(get_param(WP,"alt",0))
                        + " " + round(get_param(WP,"vel",0))
                        + " (" + round_dec(wrap_angle(get_param(WP,"lat",0)),3)
                        + "," + round_dec(wrap_angle(get_param(WP,"lng",0)),3)
                        + ")(" + round_dec(wrap_angle(get_param(WP,"elev",0)),3)
                        + "," + round_dec(wrap_angle(get_param(WP,"head",0)),3)
                        + "," + round(get_param(WP,"roll",0))
                        + ") " + round_dec(get_param(WP,"nomg",0),2).
    }
    return "".
}

local function waypoint_do_leading_action {

    
    if wp_queue:length > 0 {
        if wp_queue[0]["mode"] = "act" {
            local action_code is wp_queue[0]["do_action"].
            waypoint_remove(0).
            print "doing action from waypoint".
            if defined UTIL_SHSYS_ENABLED {
                util_shsys_do_action(action_code).
                return.
            } else {
                print "util_shsys required to do actions".
            }
            waypoint_do_leading_action().
        }
    }
}

local function waypoint_add {
    parameter pos.
    parameter new_wp.
    if pos < 0 { set pos to pos+wp_queue:length+1.}
    wp_queue:insert(pos,new_wp).
}

local function waypoint_update {
    parameter pos.
    parameter new_wp.
    if pos < 0 { set pos to pos+wp_queue:length.}
    if wp_queue:length > pos {
        set wp_queue[pos] to new_wp.
    }
}

local function waypoint_remove {
    parameter pos.
    if wp_queue:length = 0 {
        print "WPQ empty, returning".
        return.
    }
    if pos < 0 { set pos to pos+wp_queue:length.}

    if pos >= 0 and pos < wp_queue:length {
        wp_queue:REMOVE(pos).
    } else if pos = -1{
        wp_queue:REMOVE(wp_queue:length-1).
    } else {
        print "WP at pos " + pos +" does not exist".
    }
}

local function waypoint_queue_print {
    local wp_list_string is " WP (" +
        wp_queue:length + ")" + char(10).
    local i is wp_queue:iterator.
    until NOT i:next {
        set wp_list_string to wp_list_string+
            ""+ (wp_queue:length-i:index-1) +": " + waypoint_print_str(i:value) + char(10).
    }
    print wp_list_string.
    return wp_list_string.
}

local function waypoint_queue_purge {
    set wp_queue to LIST().
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
    if wp_queue[0]:haskey("complete") {
        return wp_queue[0].
    } else {
        return fill_in_waypoint_data(wp_queue[0]).
    }
}

function util_wp_status_string {
    local time_to_wp is (choose ap_nav_get_time_to_wp() if USE_AP_NAV else 0).
    if wp_queue:length > 0 {
        return "WP" + (wp_queue:length-1) +
            (choose char(10)+time_to_wp+"s" if time_to_wp>0 else "").
    } else {
        return "".
    }
}

// Returns true if message was decoded successfully
// Otherwise false
function util_wp_decode_rx_msg {
    parameter sender.
    parameter recipient.
    parameter opcode.
    parameter data.

    if not opcode:contains("WP") {
        return false.
    }

    if opcode = "OWR_WP" and data:length = 2 {
        set WP_index to data[0].
        set WP_itself to data[1].
        waypoint_update(WP_index, WP_itself).

    } else if opcode = "INS_WP" and data:length = 2 {
        set WP_index to data[0].
        set WP_itself to data[1].
        waypoint_add(WP_index, WP_itself).

    } else if opcode = "REM_WP" and data:length = 1 {
        set WP_index to data[0].
        waypoint_remove(WP_index).

    } else if opcode = "WP_PRINT"{
        util_shbus_ack(waypoint_queue_print(), sender).

    } else if opcode = "WP_PURGE"{
        waypoint_queue_purge().
        util_shbus_ack("waypoint queue purged", sender).
    } else if opcode = "WP_TAKEOFF"{
        // have to generate takoff sequence on receiving end
        if (data:length = 1) {
            local start_head is (360- (R(90,0,0)*(-SHIP:UP)*(SHIP:FACING)):yaw).
            data:insert(1,start_head).
        }
        for wp_seq_i in generate_takeoff_seq(data[0],data[1]) {
            waypoint_add(-1,
                fill_in_waypoint_data(
                    construct_incomplete_waypoint(wp_seq_i, "srf"))).
        }

    } else {
        util_shbus_ack("could not decode wp rx msg", sender).
        print "could not decode wp rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
