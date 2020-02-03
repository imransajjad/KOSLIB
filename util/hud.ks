
GLOBAL UTIL_HUD_ENABLED IS true.

IF NOT (DEFINED AP_FLCS_ROT_ENABLED) { GLOBAL AP_FLCS_ROT_ENABLED IS false.}
IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED IS false.}
IF NOT (DEFINED AP_MODE_ENABLED) { GLOBAL AP_MODE_ENABLED IS false.}
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}

local lock AG to AG3.
local PREV_AG is AG.

CLEARVECDRAWS().

local vec_info_init_draw is false.
local hud_info_init_draw is false.

local hud_text_dict_left is lexicon().
local hud_text_dict_right is lexicon().

local display_set is UTIL_HUD_START_COLOR.
local to_draw_vec is false.

local hud_interval is 2.
local hud_i is 0.

local function util_hud_vec_info {

    set guide_far to 750.
    set guide_width to 1.0.

    if not vec_info_init_draw {

        set vec_info_init_draw to true.

        set guide_tri_l TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).

        set guide_tri_r TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).

        set guide_tri_b TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).

        set guide_tri_l:wiping to false.
        set guide_tri_r:wiping to false.
        set guide_tri_b:wiping to false.

    }
    IF not is_active_vessel() or not to_draw_vec or MAPVIEW or vel < 1.0 {

        set guide_tri_l:show to false.
        set guide_tri_r:show to false.
        set guide_tri_b:show to false.
        return.
    } ELSE {

        local nav_heading is ap_nav_get_direction().
        local nav_vel is ap_nav_get_vel().

        set guide_tri_l:start to guide_far*nav_heading:vector.
        set guide_tri_l:vec to -guide_far*sin(1.0)*
            (nav_heading:starvector + 0.1*nav_heading:topvector).

        set guide_tri_r:start to guide_far*nav_heading:vector.
        set guide_tri_r:vec to guide_far*sin(1.0)*
            (nav_heading:starvector - 0.1*nav_heading:topvector).

        if vectorangle(srfprograde:vector, nav_heading:vector) < 30 {
            set guide_tri_b:start to guide_far*nav_heading:vector.
            set guide_tri_b:vec to -guide_far*sin(1.0)*nav_heading:topvector.
        } else {
            set guide_tri_b:start to guide_far*srfprograde:vector.
            set guide_tri_b:vec to guide_far*nav_heading:vector-guide_far*srfprograde:vector.
        }

        local v_color_r is min(1,max(0,-(nav_vel - vel)/100 )).
        local v_color_g is min(1,max(0,1-abs(nav_vel - vel)/100 )).
        local v_color_b is min(1,max(0,(nav_vel - vel)/100 )).

        set guide_tri_l:color to RGB( min(1,max(0,(display_set/4)*sqrt(v_color_r))),
                                    min(1,max(0,(display_set/4)*sqrt(v_color_g))),
                                    min(1,max(0,(display_set/4)*sqrt(v_color_b)))).
        set guide_tri_r:color to guide_tri_l:color.
        set guide_tri_b:color to guide_tri_l:color.

        set guide_tri_l:show to true.
        set guide_tri_r:show to true.
        set guide_tri_b:show to true.
    }
}

local land_info_init_draw is false.
local land_vec_list is list().
local function util_hud_land_info {

    if not UTIL_HUD_LAND_GUIDE {
        return.
    }
    set land_far to 750.
    set land_width to 0.25.
    set land_scale to 1.0.

    if not land_info_init_draw {

        set land_info_init_draw to true.

        if UTIL_HUD_LAND_GUIDE {

            for i in range(0,3) {
                land_vec_list:add(list( list(
                    vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
                "", land_scale, true, land_width, FALSE ),
                    vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
                "", land_scale, true, land_width, FALSE ) ),
                    0.0) ).
            }

            for bar in land_vec_list {
                for bar_vec in bar[0] {
                    set bar_vec:wiping to false.

                }
            }
        }

    }
    IF not is_active_vessel() or display_set <= 0 or MAPVIEW or vel < 1.0 or (not UTIL_HUD_LAND_GUIDE_ALWAYS_ON and not GEAR){

        for bar in land_vec_list {
            for bar_vec in bar[0] {
                set bar_vec:show to false.
            }
        }

        return.
    } else if GEAR or UTIL_HUD_LAND_GUIDE_ALWAYS_ON {

        local closest_pitch is sat(
            round(vel_pitch/UTIL_HUD_PITCH_DIV)*UTIL_HUD_PITCH_DIV,
            90-UTIL_HUD_PITCH_DIV-1).
        if GEAR and abs(-vel_pitch-UTIL_HUD_GSLOPE)<UTIL_HUD_PITCH_DIV {
            set land_vec_list[0][1] to 0.
            set land_vec_list[1][1] to -UTIL_HUD_GSLOPE.
            set land_vec_list[2][1] to -UTIL_HUD_PITCH_DIV.
        } else {
            set land_vec_list[0][1] to closest_pitch+UTIL_HUD_PITCH_DIV.
            set land_vec_list[1][1] to closest_pitch.
            set land_vec_list[2][1] to closest_pitch-UTIL_HUD_PITCH_DIV.
        }


        local set_color is RGB(0,min(display_set/4,1),0).

        for bar in land_vec_list {
            local cur_HEAD is heading(vel_bear, bar[1]).

            if bar[1] = 0 {
                set bar[0][0]:start to land_far*cur_HEAD:vector-land_far*sin(1.0)*cur_HEAD:starvector.
                set bar[0][1]:start to land_far*cur_HEAD:vector+land_far*sin(1.0)*cur_HEAD:starvector.
                
                set bar[0][0]:vec to -land_far*sin(10.0)*cur_HEAD:starvector.
                set bar[0][1]:vec to +land_far*sin(10.0)*cur_HEAD:starvector.
                set bar[0][0]:label to (choose "FLARE"
                    if (ship:altitude < UTIL_HUD_FLARE_ALT and ship:status = "FLYING") else "").
            } else {
                set bar[0][0]:start to land_far*cur_HEAD:vector.
                set bar[0][1]:start to land_far*cur_HEAD:vector.

                set bar[0][0]:vec to -land_far*(sin(2.0)*cur_HEAD:starvector-sign(bar[1])*sin(0.5)*cur_HEAD:topvector ).
                set bar[0][1]:vec to land_far*(sin(2.0)*cur_HEAD:starvector+sign(bar[1])*sin(0.5)*cur_HEAD:topvector ).
                set bar[0][0]:label to ""+round_dec(bar[1],1).
            }
            set bar[0][0]:color to set_color.
            set bar[0][1]:color to set_color.
            set bar[0][0]:show to true.
            set bar[0][1]:show to true.
        }
    }
}

local function util_hud_main_info {

    if not hud_info_init_draw {

        set hud_info_init_draw to true.


        set hud_left to GUI(151,150).
        set hud_left:draggable to false.
        set hud_left:x to 960-150-101.
        set hud_left:style:BG to "blank_tex".
        set hud_left_label to hud_left:ADDLABEL("").
        set hud_left_label:style:ALIGN to "LEFT".
        set hud_left_label:style:textcolor to RGB(0,1,0).

        set hud_left:visible to false.

        set hud_right to GUI(101,150).
        set hud_right:draggable to false.
        set hud_right:x to 960+150.
        set hud_right:style:BG to "blank_tex".

        set hud_right_label to hud_right:ADDLABEL("").
        set hud_right_label:style:ALIGN to "RIGHT".
        set hud_right_label:style:textcolor to RGB(0,1,0).

        set hud_right:visible to false.

    }

    if not (PREV_AG = AG) {
        set PREV_AG to AG.
        set display_set to display_set+1.
        if display_set >= 6 { set display_set to -1.}

        if display_set < 0 {
            set hud_left:draggable to false.
            set hud_right:draggable to false.
            if hud_left:visible { hud_left:HIDE(). }
            if hud_right:visible { hud_right:HIDE(). }

        } else if display_set < 5 {
            set hud_left_label:style:textcolor to RGB(0,display_set/4,0).
            set hud_right_label:style:textcolor to RGB(0,display_set/4,0).

        } else if display_set < 6 {
            set hud_left:draggable to true.
            set hud_right:draggable to true.
            set hud_left_label:style:textcolor to RGB(1,1,1).
            set hud_right_label:style:textcolor to RGB(1,1,1).
        }
    }

    if display_set >= 0 and not MAPVIEW and is_active_vessel() {

        local tar_str is "".

        if HASTARGET {
            if TARGET:distance < 1200 {
                set tar_str to "T"+round_dec(TARGET:distance,1).
            } else {
                set tar_str to "T"+round_dec(TARGET:distance/1000,1) + "k".
            }
            set tar_str to tar_str + "/" + 
                round_dec((target:velocity:surface-ship:velocity:surface):mag,0)
                + char(10).
        }  

        set hud_left_label:text to ""+
            ( choose ap_mode_get_str()+char(10) if AP_MODE_ENABLED else "") +
            " >> " + round(vel) +
            ( choose ap_nav_status_string()+char(10) if AP_NAV_ENABLED else char(10) ) +
            ( choose ap_flcs_rot_status_string()+char(10) if AP_FLCS_ROT_ENABLED else "") +
            hud_text_dict_left:values:join(char(10)).

        set hud_right_label:text to "" +
            round(100*THROTTLE)+
            ( choose util_shsys_status_string()+char(10) if UTIL_SHSYS_ENABLED else "") +
            round_dec(SHIP:ALTITUDE,0) +" <| " + char(10) +
            ( choose util_wp_status_string()+char(10) if UTIL_WP_ENABLED else "") +
            tar_str +
            hud_text_dict_right:values:join(char(10)).

        if not hud_left:visible { hud_left:SHOW(). }
        if not hud_right:visible { hud_right:SHOW(). }


        set to_draw_vec to (UTIL_WP_ENABLED and util_wp_queue_length() > 0) or 
            (AP_MODE_ENABLED and AP_NAV_CHECK()).
    }
    else {
        if hud_left:visible { hud_left:HIDE(). }
        if hud_right:visible { hud_right:HIDE(). }
        set to_draw_vec to false.
    }
}

function util_hud_info {
    set hud_i to hud_i+1.
    if hud_i = hud_interval {
        set hud_i to 0.
        util_hud_main_info().
    }
    util_hud_land_info().
    util_hud_vec_info().

}

function util_hud_push_left {
    parameter key.
    parameter val.
    if hud_text_dict_left:haskey(key) {
        set hud_text_dict_left[key] to val.
    } else {
        hud_text_dict_left:add(key,val).
    }   
}

function util_hud_push_right {
    parameter key.
    parameter val.
    if hud_text_dict_right:haskey(key) {
        set hud_text_dict_right[key] to val.
    } else {
        hud_text_dict_right:add(key,val).
    }   
}

function util_hud_pop_left {
    parameter key.
    if hud_text_dict_left:haskey(key) {
        hud_text_dict_left:remove(key).
    }
}

function util_hud_pop_right {
    parameter key.
    if hud_text_dict_right:haskey(key) {
        hud_text_dict_right:remove(key).
    }
}


// RX SECTION

function util_hud_decode_rx_msg {
    parameter received.

    set opcode to received:content[0].
    if not opcode:startswith("HUD") {
        return.
    } else if received:content:length > 1 {
        set data to received:content[1].
    }
    if opcode = "HUD_PUSHL" {
        util_hud_push_left(data[0],data[1]).
    } else if opcode = "HUD_PUSHR" {
        util_hud_push_right(data[0],data[1]).
    } else if opcode = "HUD_POPL" {
        hud_text_dict_left:remove(data[0]).
    } else if opcode = "HUD_POPR" {
        hud_text_dict_right:remove(data[0]).
    } else {
        util_shbus_rx_send_back_ack("could not decode hud rx msg").
        print "could not decode hud rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
