
GLOBAL TARGET_RADAR_ENABLED IS true.

lock AG to AG1.
local prev_AG is AG.

local lock line_of_sight to ship:facing.

local next_lock_index is 0.
local scan_timeout is 0.

local target_list is list().

local status_str is "".

set scan_timeout_max to 10.
IF NOT (DEFINED FLCS_PROC) {GLOBAL FLCS_PROC IS 0. } // required global.

local hudtext_sent is false.

local debug_str is "".

local data_width is 12.
local view_width is TERMINAL:WIDTH-data_width.
local view_height is TERMINAL:HEIGHT-1.


local function print_debug {
    parameter str_in.
    set debug_str to debug_str+str_in.
    print debug_str AT(view_width,0).
}

local function set_status {
    parameter str_in.
    set status_str to str_in.
}

local function print_status {
    print status_str at(view_width,0).
}

local function print_target_data {
    
    if next_lock_index > 0 {
        if scan_timeout > 0 {
            print next_lock_index + "/" +target_list:length at(view_width, 1).
        } else {
            print next_lock_index + "/" +target_list:length at(view_width, 1).
        }
    } else {
        if scan_timeout > 0 {
            print "-/"+target_list:length at(view_width, 1).
        } else {
            print "-/"+target_list:length at(view_width, 1).
        }
    }

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
        
        local vel_str is round_dec((target_ship:velocity:orbit-ship:velocity:orbit):mag,0).

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


local function do_debug_print {
    print debug_str AT(0,TERMINAL:HEIGHT-1).
    set debug_str to "".
}

local my_fullname is ship:name+"+"+core:tag.
local flcs_tag is "flcs".

local function hudtext {
    parameter ttext.
    if (FLCS_PROC = 0) or hudtext_sent { return.}
    if not FLCS_PROC:CONNECTION:SENDMESSAGE(list(my_fullname,flcs_tag,"HUD_PUSHR",list(core:tag, ttext))) {
        print "could not send message HUD_PUSHR".
    }
    set hudtext_sent to true.
}

local function hudtext_remove {
    if (FLCS_PROC = 0) or not hudtext_sent { return.}
    if not FLCS_PROC:CONNECTION:SENDMESSAGE(list(my_fullname,flcs_tag,"HUD_POPR",list(core:tag))) {
        print "could not send message HUD_POPR".
    }
    set hudtext_sent to false.
}

local function do_scan {
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


function target_radar_update_target{
    if AG <> prev_AG {
        set prev_AG to AG.
        if scan_timeout = 0 {
            if next_lock_index = 0 {
                do_scan().
                if target_list:length > 0 {
                    set scan_timeout to scan_timeout_max.
                    hudtext("sR"+target_list:length ).
                    set_status("scanned").
                }
            } else {
                set_status("").
                just_unlock().
                set next_lock_index to 0.
            }
        } else {
            if next_lock_index = target_list:length {
                set_status("").
                just_unlock().
                set scan_timeout to 0.
                set next_lock_index to 0.
            } else {
                set_status("locked").
                do_lock().
                set next_lock_index to next_lock_index+1.
                set scan_timeout to scan_timeout_max.

            }
        }
    }
    set scan_timeout to max(0, scan_timeout - Ts).
    if scan_timeout = 0 {
        set_status("").
        hudtext_remove().
    }
}



function get_screen_position {
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
    print round_dec( (2^max_distance_log)/1000,1) AT(0,0).
    print round_dec( (2^min_distance_log)/1000,1) AT(0,view_height).

    //do_debug_print().
    print_status().
    print_target_data().
}
