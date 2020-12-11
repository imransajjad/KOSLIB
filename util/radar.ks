
GLOBAL UTIL_RADAR_ENABLED IS true.


local PARAM is get_param(readJson("param.json"), "UTIL_RADAR", lexicon()).

local max_angle is 20.
local MAX_ENERGY is get_param(PARAM, "MAX_ENERGY", 0). // distance at 1 deg beam
local max_range is MAX_ENERGY/(max_angle^2).

local LOOKUP_DIRECTION is R(0,0,0).

local Ts is get_param(PARAM, "DISPLAY_UPDATE_PERIOD", 1.0).
local scan_timeout_per_target is get_param(PARAM, "TARGET_SCAN_TIMEOUT", 5).

lock AG to AG1.
local prev_AG is AG.

local next_lock_index is 0.
local scan_timeout is 0.

local target_list is list().

local status_str is "".

local debug_str is "".

local data_width is 12.
lock view_width to TERMINAL:WIDTH-data_width.
lock view_height to TERMINAL:HEIGHT-1.



local function print_debug {
    parameter str_in.
    set debug_str to debug_str+str_in.
}

local function do_debug_print {
    print "debug_str: " + debug_str AT(0,TERMINAL:HEIGHT-1).
    set debug_str to "".
}

local function set_status {
    parameter str_in.
    set status_str to str_in.
    if status_str = "" {
        util_shbus_tx_msg("HUD_POPR",list(core:tag), list("flcs")).
    } else {
        util_shbus_tx_msg("HUD_PUSHR",list(core:tag, status_str), list("flcs")).
    }
}

local function print_status {
    local i is status_str:split(char(10)):iterator.
    until not i:next {
        print i:value at (view_width,0+i:index).
    }
    // print status_str at(view_width,0).
}

local function print_target_data {
    
    if not HASTARGET {
        print "         " at (view_width,3).
        print "         " at (view_width,4).
        print "         " at (view_width,5).
    } else {
        local target_ship is TARGET.
        if not TARGET:hassuffix("velocity") {
            set target_ship to TARGET:ship.
        }
        local dist_str is "".
        
        local rel_vel is target_ship:velocity:orbit-ship:velocity:orbit.
        local vel_str is (choose "-" if rel_vel*ship:facing:vector > 0 else "") +round_dec(rel_vel:mag,0).

        if target_ship:distance < 1200 { set dist_str to ""+round_dec(target_ship:distance,1).}
        else { set dist_str to ""+round_dec(target_ship:distance/1000,1) + "k".}

        print dist_str at (view_width,3).
        print vel_str at (view_width,4).

        local i is TARGET:name:split(" "):iterator.
        until not i:next {
            print i:value at (view_width,7+i:index).
        }
        
    }
}

local scan_visual is VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1,0),"", 1.0, false, 0.25, false ).
clearvecdraws().
local function scan_visual_show {
    set scan_visual:show to true.
    for i in range(0,360,10) {
        set scan_visual:start to 100*(ship:facing*LOOKUP_DIRECTION:vector).
        set scan_visual:vec to 100*tan(max_angle)*(ship:facing*LOOKUP_DIRECTION*R(0,0,i)*V(1,0,0)).
        wait 0.
    }
    set scan_visual:show to false.
}

local function do_scan {
    list targets in target_list.
    local removal_list is list().

    // remove max_range
    local ti is target_list:iterator.
    until not ti:next {
        if (ti:value:distance > max_range) or 
        (vectorangle(ti:value:position, ship:facing*LOOKUP_DIRECTION:vector) > max_angle) {
            removal_list:add(ti:index).
        }
    }
    local decrementer is 0.
    for i in removal_list {
        target_list:remove(i-decrementer).
        set decrementer to decrementer+1.
    }

    for i in target_list {
        //print i.
    }
    scan_visual_show().
}

local function unlock_target {
    set_status("").
    set TARGET TO "".
    set target_list to list().
    set next_lock_index to 0.
    set scan_timeout to 0.
}

function target_radar_update_target{
    if scan_timeout = 0 {
        if next_lock_index = 0 {
            do_scan().
            if target_list:length > 0 {
                set scan_timeout to scan_timeout_per_target*target_list:length.
                set_status("scanned" + char(10) +"-/" + target_list:length).
            } else {
                set scan_timeout to 1.
                set_status("no tar").
            }
        } else {
            unlock_target().
        }
    } else {
        if next_lock_index = target_list:length {
            unlock_target().
        } else {
            set_status("locked" + char(10) + (next_lock_index+1)+"/" + target_list:length).
            if not target_list[next_lock_index]:isdead {
                set TARGET TO target_list[next_lock_index].
            }
            set next_lock_index to next_lock_index+1.
        }
    }
}


function scan_timeout_do {
    if scan_timeout > 0 {
        set scan_timeout to max(0, scan_timeout - Ts).
        if scan_timeout = 0 {
            set_status("").
        }
    }
}


local function get_screen_position {
    parameter dist.
    parameter bear.
    parameter min_dist.
    parameter max_dist.

    local max_width is TERMINAL:WIDTH-12.
    local max_height is TERMINAL:HEIGHT-5.

    local y is (dist-min_dist)/(max_dist-min_dist)*(max_height).
    local x is (bear+max_angle)/(2*max_angle)*max_width.
    local flag is (x >= 0 and x < max_width).
    
    set x to min(max_width, max(x,0)).
    set y to min(max_height-1, max(0, max_height-y )).
    return list(x, y, flag).
} 


function target_radar_draw_picture {

    local min_distance_log is 1.
    local max_distance_log is 5.
    local temp_log is 0.
    if target_list:length > 0 {
        // draw all targets from last Scan
        set min_distance_log to 100.
        set max_distance_log to 0.
        
        for t in target_list {
            set temp_log to ln(t:distance)/ln(2).
            if temp_log > max_distance_log { set max_distance_log to temp_log.}
            if temp_log < min_distance_log { set min_distance_log to temp_log.}
        }

        set min_distance_log to floor(min_distance_log).
        set max_distance_log to ceiling(max_distance_log).
    }

    CLEARSCREEN.
    for t in target_list {
        local screen_pos is get_screen_position(t:distance, t:bearing, 2^min_distance_log, 2^max_distance_log).
        if screen_pos[2] {
            print "." at(screen_pos[0],screen_pos[1]).
        }
    }
    if HASTARGET {
        local target_ship is TARGET.
        if not TARGET:hassuffix("velocity") {
            set target_ship to TARGET:ship.
        }
        local screen_pos is get_screen_position(target_ship:distance, target_ship:bearing, 2^min_distance_log, 2^max_distance_log).
        print "x" at(screen_pos[0],screen_pos[1]).
    }
    // print min max distance
    if target_list:length > 0 {
        print round_dec( (2^max_distance_log)/1000,1) AT(0,0).
        print round_dec( (2^min_distance_log)/1000,1) AT(0,view_height).
    } else if not HASTARGET {
        if ship:control:pilottranslation:mag > 0 {
            set LOOKUP_DIRECTION to R(
                sat(LOOKUP_DIRECTION:pitch - ship:control:pilottop,30),
                sat(LOOKUP_DIRECTION:yaw + ship:control:pilotstarboard,30),
                0).
            set max_angle to max(0.5,min(45,max_angle - 0.5*ship:control:pilotfore)).
            set max_range to MAX_ENERGY/(max_angle^2).
        }
        print "radar".
        print " use AG to scan".
        print " and cycle targets".
        print " use AG twice to exit".
        print " translation to steer beam".
        print " max range: " + round_dec(max_range/1000,2) +"k".
        print " max angle: " + round_dec(max_angle,2) +" deg".
        print " pitch: " + round_dec(-LOOKUP_DIRECTION:pitch,2) +" deg".
        print " yaw: " + round_dec(LOOKUP_DIRECTION:yaw,2) +" deg".
    }

    // do_debug_print().
    print_status().
    print_target_data().
}

function util_radar_loop {
    local nAG is 0.
    local nAG_final is 0.
    local start_time is 0.

    on AG {
        set nAG to nAG+1.
        
        // start a timer to *collect* button presses
        if start_time = 0 {
            set start_time to time:seconds.
            on (time:seconds > start_time+Ts) {
                set nAG_final to nAG.
                set nAG to 0.
                set start_time to 0.
                return false.
            }
        }
        return true.
    }

    until false {
        if nAG_final >= 2 and target_list:length = 0 {
            CLEARSCREEN.
            set_status("").
            return.
        } else if nAG_final = 2 {
            unlock_target().
        } else if nAG_final = 1 {
            target_radar_update_target().
        }
        target_radar_draw_picture().
        scan_timeout_do().
        set nAG_final to 0.
        wait Ts.
    }
}

// terminal compatible functions
function util_radar_get_help_str {
    return list(
        "UTIL_RADAR running on "+core:tag,
        "radar  turn on radar",
        "press AG once to cycle targets",
        "press AG twice to go back"
        ).
}

function util_radar_parse_command {
    parameter commtext.
    parameter args is list().

    set target_list to list().
    set next_lock_index to 0.
    set scan_timeout to 0.

    if commtext = "radar" {
        if MAX_ENERGY <= 0 {
            print "radar not available".
            return true.
        }
        util_radar_loop().
        print "radar exiting".
        return true.
    } else if commtext = "radar help" {
        util_term_parse_command("help RADAR").
        return true.
    } else {
        return false.
    }
}
