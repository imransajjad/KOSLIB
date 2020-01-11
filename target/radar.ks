
GLOBAL TARGET_RADAR_ENABLED IS true.

lock AG to AG1.
local prev_AG is AG.

local lock line_of_sight to ship:facing.

local next_lock_index is 0.
local scan_timeout is 0.

local target_list is list().

local status_str is "".

set scan_timeout_max to 10.

local flcs_proc is processor("FLCS").
local hudtext_sent is false.

local debug_str is "".

CLEARSCREEN.

local function hudtext {
    parameter ttext.
    if hudtext_sent { return.}
    if not flcs_proc:CONNECTION:SENDMESSAGE(list("HUD_PUSHR",list(core:tag, ttext))) {
        print "could not send message HUD_PUSHR".
    }
    set hudtext_sent to true.
}

local function hudtext_remove {
    if not hudtext_sent { return.}
    if not flcs_proc:CONNECTION:SENDMESSAGE(list("HUD_POPR",list(core:tag))) {
        print "could not send message HUD_POPR".
    }
    set hudtext_sent to false.
}

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
            print "tar: " + next_lock_index + "/" +target_list:length + "/scv" at(TERMINAL:WIDTH-15, 0).
        } else {
            print "tar: " + next_lock_index + "/" +target_list:length at(TERMINAL:WIDTH-15, 0).
        }
    } else {
        if scan_timeout > 0 {
            print "no tar/"+target_list:length + "/scv" at(TERMINAL:WIDTH-15, 0).
        } else {
            print "no tar/"+target_list:length at(TERMINAL:WIDTH-15, 0).
        }

    }
}

local function do_debug_print {
    print debug_str AT(0,TERMINAL:HEIGHT-1).
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
                    hudtext("sR"+target_list:length ).
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
    if scan_timeout = 0 {
        hudtext_remove().
    }
}



function get_screen_position {
    parameter dist.
    parameter bear.
    parameter min_dist.
    parameter max_dist.

    local y is (dist-min_dist)/(max_dist-min_dist)*(TERMINAL:HEIGHT-5).
    local x is (bear+max_angle)/(2*max_angle)*TERMINAL:WIDTH.
    local flag is (x >= 0 and x < TERMINAL:WIDTH).
    
    set x to min(TERMINAL:WIDTH, max(x,-1)).
    set y to min(TERMINAL:HEIGHT-4, max(-1, TERMINAL:HEIGHT-5-y )).
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
        local dist_str is "".
        local vel_str is round_dec((target:velocity:surface-ship:velocity:surface):mag,0).

        if TARGET:distance < 1200 { set dist_str to ""+round_dec(TARGET:distance,1).}
        else { set dist_str to ""+round_dec(TARGET:distance/1000,1) + "k".}

        local screen_pos is get_screen_position(TARGET:distance, TARGET:bearing, 2^min_distance_log, 2^max_distance_log).
        if screen_pos[0] >= 0 and screen_pos[0] < TERMINAL:WIDTH  and
           screen_pos[1] >= 0 and screen_pos[1] < TERMINAL:HEIGHT-4 {
            if screen_pos[0] < TERMINAL:WIDTH-dist_str:length-1 {
                print "X|"+dist_str at(screen_pos[0],screen_pos[1]).
                print vel_str at(screen_pos[0],screen_pos[1]+1).
            } else {
                print dist_str+"|X" at(screen_pos[0]-dist_str:length,screen_pos[1]).
                print vel_str at(screen_pos[0]-dist_str:length,screen_pos[1]+1).
            }
        } else {
            print "X" at(screen_pos[0],screen_pos[1]).
        }

        print TARGET:name at (0,TERMINAL:HEIGHT-4).
        print dist_str at (0,TERMINAL:HEIGHT-3).
        print vel_str at (0,TERMINAL:HEIGHT-2).
    }
    // print min max distance
    print round_dec( (2^max_distance_log)/1000,1) AT(0,0).
    print round_dec( (2^min_distance_log)/1000,1) AT(0,TERMINAL:HEIGHT-5).
    do_debug_print().
    print_status().
}
