
IF NOT (DEFINED TARGET_RADAR_ENABLED) { GLOBAL TARGET_RADAR_ENABLED IS true.}

lock AG to AG1.
local prev_AG is AG.

local lock line_of_sight to ship:facing.

local next_lock_index is 0.
local scan_timeout is 0.

local target_list is list().

local status_str is "".

local function x_to_term {
    parameter x.
    return min(TERMINAL:WIDTH-1, max(x,0)).
}
local function y_to_term {
    parameter y.
    return min(TERMINAL:HEIGHT-3, max(0, TERMINAL:HEIGHT-3-y )).
}

set scan_timeout_max to 10.


local debug_str is "".

CLEARSCREEN.

local function do_scan {
    //write_debug("Initiating Scan").
    list targets in target_list.
    local removal_list is list().

    // remove max_range
    local ti is target_list:iterator.
    until not ti:next {
        if (ti:value:distance > max_range) or 
        (vectorangle(ti:value:position,line_of_sight:vector) > max_angle) {
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
}


local function just_unlock {
    set TARGET TO "".
    set target_list to list().
}


local function do_lock {
    set TARGET TO target_list[next_lock_index].
}


local function print_debug {
    parameter str_in.
    set debug_str to debug_str+str_in.
}

local function print_status {

    if next_lock_index > 0 {
        if scan_timeout > 0 {
            print "tar: " + next_lock_index + "/" +target_list:length + "/scv" at(x_to_term(TERMINAL:WIDTH-15), y_to_term(1000)).
        } else {
            print "tar: " + next_lock_index + "/" +target_list:length at(x_to_term(TERMINAL:WIDTH-15), y_to_term(1000)).
        }
    } else {
        if scan_timeout > 0 {
            print "no tar/"+target_list:length + "/scv" at(x_to_term(TERMINAL:WIDTH-15), y_to_term(1000)).
        } else {
            print "no tar/"+target_list:length at(x_to_term(TERMINAL:WIDTH-15), y_to_term(1000)).
        }

    }
}

local function do_debug_print {
    print debug_str AT(0,TERMINAL:HEIGHT-2).
    set debug_str to "".
}

function target_radar_update_target{
    if AG <> prev_AG {
        set prev_AG to AG.
        if scan_timeout = 0 {
            if next_lock_index = 0 {
                print_debug("scanning").
                do_scan().
                if target_list:length > 0 {
                    set scan_timeout to scan_timeout_max.
                }
            } else {
                print_debug("unlock for newscan").
                just_unlock().
                set next_lock_index to 0.
            }
        } else {
            PRINT "here".
            if next_lock_index = target_list:length {
                print_debug("unlock cause last target").
                just_unlock().
                set scan_timeout to 0.
                set next_lock_index to 0.
            } else {
                print_debug("locking").
                do_lock().
                set next_lock_index to next_lock_index+1.
                set scan_timeout to scan_timeout_max.

            }
        }
    }
    set scan_timeout to max(0, scan_timeout - Ts).
}



function get_screen_position {
    parameter dist.
    parameter bear.
    parameter min_dist.
    parameter max_dist.

    local y is (dist-min_dist)/(max_dist-min_dist)*(TERMINAL:HEIGHT-2).
    local x is (bear+max_angle)/(2*max_angle)*TERMINAL:WIDTH.
    local flag is (x >= 0 and x < TERMINAL:WIDTH).
    
    set x to min(TERMINAL:WIDTH-1, max(x,0)).
    set y to min(TERMINAL:HEIGHT-5, max(0, TERMINAL:HEIGHT-5-y )).
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
        local screen_pos is get_screen_position(TARGET:distance, TARGET:bearing, 2^min_distance_log, 2^max_distance_log).
        if screen_pos[0] < TERMINAL:WIDTH-4 {
            print "X|"+round_dec(TARGET:distance/1000,1) at(screen_pos[0],screen_pos[1]).
        } else {
            print round_dec(TARGET:distance/1000,1)+"|X" at(screen_pos[0],screen_pos[1]).
        }
    }
    // print min max distance
    print round_dec( (2^max_distance_log)/1000,1) AT(x_to_term(0),y_to_term(1000)).
    print round_dec( (2^min_distance_log)/1000,1) AT(x_to_term(0),y_to_term(0)).
    do_debug_print().
    print_status().
    IF HASTARGET {
        print TARGET:name at (0,TERMINAL:HEIGHT-2).
    }
    //print_debug().
}
