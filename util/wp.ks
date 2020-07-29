
// Required Dependencies
// UTIL_SHBUS_TX_ENABLED
// UTIL_SHBUS_RX_ENABLED

// a waypoint, (WP) is now a dictionary that can contain complete or limited
// information about where to go. It follows a few basic rules
//
// types: act, spin, srf, orb, tar
// act (action group):
//  action basically does toggles an action group
// srf (surface):
//  atmosphere surface location has an SOI body and is meant to be
//  used inside an atmosphere, positions and everything are relative to surface
// orb (space nav):
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
}
if PARAM:haskey("AP_AERO_W") and get_param(PARAM["AP_AERO_W"], "USE_GCAS", false) {
    set GCAS_ALTITUDE to get_param(PARAM["AP_AERO_W"], "GCAS_MARGIN", GCAS_ALTITUDE).
}

local wp_queue is LIST().

if exists("wp_queue.json") {
    set wp_queue to readJson("wp_queue.json").
}
local cur_mode is "srf".

// wp_queue is LIST of WAYPOINTS
// WAYPOINT is LIST containing [lat, long, h, vel]
// if vel is zero, vel can be set by us


// TX SECTION

// many commands are mostly permutations of these
// five messages

// this function will be used by shbus_tx
local function wp_arg_lex {
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
    } else if wp["mode"] = "orb" {
        // not implemented yet, setting invalid action
        set wp["mode"] to "act".
        set wp["do_action"] to -99.
        return wp.
    } else if wp["mode"] = "tar" {
        local L is wp_args:length.
        if L >= 1 { set wp["speed"] to wp_args[0]. }
        if L >= 2 { set wp["radius"] to wp_args[1].}
        if L >= 5 { set wp["offsvec"] to V(wp_args[2],wp_args[3],wp_args[4]).}
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

function util_wp_get_help_str {
    return LIST(
        "UTIL_WP running on "+core:tag,
        "wpoverwrite(i,WP) [wpo] overwrite wp",
        "wpinsert(i,WP)    [wpi] insert wp",
        "wpremove(i)       [wpr] remove wp ",
        "wpswap(i,j)       [wps] swap wps",
        "wpqueueprint      [wpqp] print wp list",
        "wpqueuedelete     [wpqd] purge wp list",
        "wpmode str        [wpmd] str is act, spin, srf, orb, tar",
        "wpdelete          [wpd] delete first wp",
        "wpfirst(WP)       [wpf] add wp to first ",
        "wpadd(WP)         [wpa] add wp to last ",
        "wpupdate(WP)      [wpu] first wp write",
        "wptarget(WP)      [wpt] vessel/nav target wp",
        "wphome(alt,vel)   [wpk] go home (srf)",
        "wptakeoff(distance,heading) [wpto] takeoff (srf)",
        "wpland(distance,vel,GSlope,heading) [wpl] landing (srf)",
        " in srf mode:",
        "  WP = alt,vel",
        "  WP = alt,vel,lat,lng",
        "  WP = alt,vel,lat,lng,pitch,bear",
        " in tar mode:",
        "  WP = speed,radius",
        "  WP = speed,radius,offx,offy,offz",
        "depends on UTIL_SHBUS, is a way to schedule waypoints and actions.",
        "Commands usually have a shortened version. Messages are received and possibly serviced by SHBUS hosts."
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
        list(start_alt, 350, p1[0], p1[1], 0, heading),
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
    local alt_stp is latlng(lat_stp,lng_stp):terrainheight+1.0.

    local stop_dist is 1000.
    set GSlope to abs(GSlope).
    local LSlope is 0.15.
    local dist2arc is RAD2DEG/ship:body:radius.
    local flare_sd is 1.0. // flare slowdown

    local flare_radius is max(10*(flare_sd*speed)/((GSlope-LSlope)*DEG2RAD),
                (flare_sd*speed)^2/((NOM_NAV_G/4)*g0) ).
                    // at least 10 second flare or what navg allows
    local flare_g is (flare_sd*speed)^2/flare_radius/g0.

    local flare_long is flare_radius*(sin(GSlope) - sin(LSlope)).
    local flare_h is flare_radius*(cos(LSlope)-cos(GSlope)).

    local p5 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance)*dist2arc).
    local p4 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/2)*dist2arc).
    local p3 is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long+distance/10)*dist2arc).
    local p2f is haversine_latlng(lat_stp,lng_stp,runway_angle+180, (stop_dist+flare_long)*dist2arc).
    local p1td is haversine_latlng(lat_stp,lng_stp,runway_angle+180,stop_dist*dist2arc).
    // local p1stp is haversine_latlng(lat_stp,lng_stp,0, 0).

    local landing_sequence is LIST(
    list(alt_stp + flare_h +distance*tan(GSlope), speed, p5[0], p5[1], -GSlope,runway_angle),
    list(alt_stp + flare_h +distance*tan(GSlope)/2, speed, p4[0], p4[1],-GSlope,runway_angle),
    list(alt_stp + flare_h +distance*tan(GSlope)/10, speed, p3[0], p3[1],-GSlope,runway_angle),
    list(alt_stp + flare_h, speed, p2f[0], p2f[1], -GSlope,runway_angle),
    list(alt_stp , flare_sd*speed,    p1td[0], p1td[1], -LSlope,runway_angle,flare_g),
    list(alt_stp-1.0, 0, lat_stp, lng_stp, -0,runway_angle,flare_g)).

    local gcas_gear_wp is -1.
    if GCAS_ALTITUDE > 0 {
        local i is landing_sequence:iterator.
        until not i:next {
            if (i:value[0] < alt_stp + GCAS_ALTITUDE ) {
                set gcas_gear_wp to i:index.
                break.
            }
        }
    }
    if gcas_gear_wp > -1 {
        landing_sequence:insert(gcas_gear_wp, list("g")).
    } else {
        landing_sequence:insert(4, list("g")).
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

    if commtext:startswith("wpo") or commtext:startswith("wpoverwrite") {
        overwrite_waypoint(-args[0]-1, wp_arg_lex(args:sublist(1,args:length-1), cur_mode) ).
    } else if commtext:startswith("wpi") or commtext:startswith("wpinsert")  {
        insert_waypoint(-args[0]-2, wp_arg_lex(args:sublist(1,args:length-1), cur_mode) ).
    } else if commtext:startswith("wpr") or commtext:startswith("wpremove"){
        remove_waypoint(-args[0]-1).
    } else if commtext:startswith("wps") or commtext:startswith("wpswap"){
        print "not implmented yet".
    } else if commtext = "wpqp" or commtext = "wpqueueprint" {
        util_shbus_tx_msg("WP_PRINT").
    } else if commtext = "wpqd" or commtext = "wpqueuepurge" {
        util_shbus_tx_msg("WP_PURGE").
    } else if commtext:startswith("wpmd") or commtext:startswith("wpmode"){
        if not brackets and ((args = "act") or (args = "spin") or (args = "srf") or (args = "orb") or (args = "tar")){
            set cur_mode to args.
        } else {
            print "wp mode " + args + " not supported".
        }
    } else if commtext = "wpd" or commtext = "wpdelete" { 
        remove_waypoint(0).
    } else if commtext:startswith("wpf") or commtext:startswith("wpfirst"){ 
        insert_waypoint(0, wp_arg_lex(args, cur_mode) ).
    } else if commtext:startswith("wpa") or commtext:startswith("wpadd"){ 
        insert_waypoint(-1, wp_arg_lex(args, cur_mode) ).
    } else if commtext:startswith("wpu") or commtext:startswith("wpupdate"){
        overwrite_waypoint(0, wp_arg_lex(args, cur_mode) ).
    } else if (commtext:startswith("wpt(")  or commtext:startswith("wptarget")) 
        and args:length = 2 {
        if is_active_vessel() and HASTARGET {
            print "Found Target.".
            insert_waypoint(-1,
                wp_arg_lex(list(args[0],args[1],TARGET:GEOPOSITION:LAT,
                    TARGET:GEOPOSITION:LNG), cur_mode) ).
            return true.
        } else if is_active_vessel() {
            for WP_TAR in ALLWAYPOINTS() {
                if (WP_TAR:ISSELECTED) {
                    print "Found navigation waypoint".
                    insert_waypoint(-1,
                    wp_arg_lex(list(args[0],args[1],WP_TAR:GEOPOSITION:LAT,
                        WP_TAR:GEOPOSITION:LNG), cur_mode) ).
                    return true.
                }
            }
        }
        print "Could not find target or navigation waypoint".
    } else if (commtext:startswith("wpk(") or commtext:startswith("wphome(")) 
        and args:length = 2 {
        insert_waypoint(-1,
            wp_arg_lex(list(args[0],args[1],-0.048,
                -74.69), cur_mode) ).
    } else if (commtext:startswith("wpl(") or commtext:startswith("wpland(")) 
        and (args:length = 3 or args:length = 4) {
        util_shbus_tx_msg("WP_LAND", args). // special command for landing
    } else if (commtext:startswith("wpto(") or commtext:startswith("wptakeoff(")) 
        and (args:length = 1 or args:length = 2) {
        util_shbus_tx_msg("WP_PURGE").
        util_shbus_tx_msg("WP_TAKEOFF", args). // special command for take off
    } else {
        return false.
    }
    return true.
}

// TX SECTION END

// RX SECTION

local function waypoint_print_str {
    parameter WP.
    if WP["mode"] = "act" {
        return WP["mode"] + " " + WP["do_action"].
    } else if WP["mode"] = "srf" {
        local wp_str is WP["mode"].
        set wp_str to wp_str + " " + round(get_param(WP,"alt",0))
                        + " " + round(get_param(WP,"vel",0)).
        if wp:haskey("lat") {
            set wp_str to wp_str + " (" + round_dec(wrap_angle(get_param(WP,"lat",0)),3)
                        + "," + round_dec(wrap_angle(get_param(WP,"lng",0)),3) + ")".
        }
        if wp:haskey("elev") {
            set wp_str to wp_str + "(" + round_dec(wrap_angle(get_param(WP,"elev",0)),1)
                        + "," + round_dec(wrap_angle(get_param(WP,"head",0)),1) + ")".
        }
        if wp:haskey("roll") {
            set wp_str to wp_str + "(" + round_dec(wrap_angle(get_param(WP,"pitch",0)),2)
                        + "," + round_dec(wrap_angle(get_param(WP,"yaw",0)),2)
                        + "," + round_dec(wrap_angle(get_param(WP,"roll",0)),2) + ")".
        }
        if wp:haskey("nomg") {
            set wp_str to wp_str + " " + round_dec(get_param(WP,"nomg",0),2).
        }
        return wp_str.
    } else if WP["mode"] = "tar" {
        local wp_str is WP["mode"].
        if wp:haskey("speed") {
            set wp_str to wp_str + " " + round_dec(get_param(WP, "speed", 1.0),1).
        }
        if wp:haskey("radius") {
            set wp_str to wp_str + " " + round(get_param(wp, "radius", 1.0)).
        }
        if wp:haskey("offsvec") {
            local offsvec is get_param(WP, "offsvec", V(0,0,0)).
            set wp_str to wp_str + " (" +
                round_dec(offsvec:x,2) + " " + round_dec(offsvec:y,2) + " " +
                round_dec(offsvec:z,2) + ")".
        }
        return wp_str.
    }
    return "".
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
    waypoint_remove(0).
    writeJson(wp_queue, "wp_queue.json"). // only other place wp updated
}

function util_wp_queue_length {
    return wp_queue:length.
}

function util_wp_queue_last {
  return wp_queue[wp_queue:length-1].
}

function util_wp_queue_first {
    return wp_queue[0].
}

function util_wp_status_string {
    local time_to_wp is (choose ap_nav_get_time_to_wp() if defined AP_NAV_ENABLED else 0).
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
    } else if opcode = "WP_LAND" {
        if data:length = 3 {
            data:insert(3,90.4+(choose 180 if ship:geoposition:lng > -74.69 else 0) ).
        }
        for wp_seq_i in generate_landing_seq(data[0],data[1],data[2],data[3]) {
            waypoint_add(-1,
                wp_arg_lex(wp_seq_i, "srf") ).
        }
    } else if opcode = "WP_TAKEOFF"{
        // have to generate takoff sequence on receiving end
        if (data:length = 1) {
            local start_head is (360- (R(90,0,0)*(-SHIP:UP)*(SHIP:FACING)):yaw).
            data:insert(1,start_head).
        }
        for wp_seq_i in generate_takeoff_seq(data[0],data[1]) {
            waypoint_add(-1, wp_arg_lex(wp_seq_i, "srf")).
        }

    } else {
        util_shbus_ack("could not decode wp rx msg", sender).
        print "could not decode wp rx msg".
        return false.
    }
    // since this is one of the only two ways to update the waypoint queue
    // we can write the waypoints to file here, even if they are incomplete.
    writeJson(wp_queue, "wp_queue.json").
    return true.
}

// RX SECTION END
