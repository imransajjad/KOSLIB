
GLOBAL UTIL_HUD_ENABLED IS true.

IF NOT (DEFINED AP_FLCS_ROT_ENABLED) { GLOBAL AP_FLCS_ROT_ENABLED IS false.}
IF NOT (DEFINED AP_MODE_ENABLED) { GLOBAL AP_MODE_ENABLED IS false.}
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}

local lock AG to AG3.
local PREV_AG is AG.

CLEARVECDRAWS().

local hud_text_dict_left is lexicon().
local hud_text_dict_right is lexicon().

local display_set is UTIL_HUD_START_COLOR.
local display_status_strs is list(" ","\" ,"-", "/","|","c").
local lock camera_offset_vec to SHIP:CONTROLPART:position + 
    UTIL_HUD_CAMERA_HEIGHT*ship:facing:topvector + 
    UTIL_HUD_CAMERA_RIGHT*ship:facing:starvector.

// draw a vector on the ap_nav desired heading
local nav_init_draw is false.
local guide_tri_ll is 0.
local guide_tri_lr is 0.
local guide_tri_tl is 0.
local guide_tri_tr is 0.
local function nav_vecdraw {
    local guide_far is 300.
    local guide_width is 0.4.
    local guide_size is 0.5.

    if not nav_init_draw {
        IF NOT (DEFINED AP_NAV_ENABLED) or not (DEFINED UTIL_HUD_NAVVEC) {
            return.
        }

        set nav_init_draw to true.

        set guide_tri_ll TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).
        set guide_tri_lr TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).

        set guide_tri_tl TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).
        set guide_tri_tr TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, guide_width, FALSE ).


        set guide_tri_ll:wiping to false.
        set guide_tri_lr:wiping to false.
        set guide_tri_tl:wiping to false.
        set guide_tri_tr:wiping to false.

    }
    if is_active_vessel() and display_set > 0 and not MAPVIEW and 
       (( DEFINED UTIL_WP_ENABLED and util_wp_queue_length() > 0 ) or
        ( DEFINED AP_MODE_ENABLED and DEFINED AP_NAV_ENABLED and AP_MODE_NAV)){

        local nav_heading is ap_nav_get_direction().
        local nav_vel is ap_nav_get_vel().
        local camera_offset is camera_offset_vec.

        set guide_tri_ll:start to camera_offset+guide_far*(nav_heading:vector-sin(guide_size)*nav_heading:starvector).
        set guide_tri_ll:vec to guide_far*sin(guide_size)*
            (nav_heading:starvector - nav_heading:topvector).

        set guide_tri_lr:start to camera_offset+guide_far*(nav_heading:vector+sin(guide_size)*nav_heading:starvector).
        set guide_tri_lr:vec to guide_far*sin(guide_size)*
            (-nav_heading:starvector - nav_heading:topvector).

        set guide_tri_tl:start to camera_offset+guide_far*(nav_heading:vector-sin(guide_size)*nav_heading:starvector).
        set guide_tri_tl:vec to guide_far*sin(guide_size)*
            (nav_heading:starvector + nav_heading:topvector).

        set guide_tri_tr:start to camera_offset+guide_far*(nav_heading:vector+sin(guide_size)*nav_heading:starvector).
        set guide_tri_tr:vec to guide_far*sin(guide_size)*
            (-nav_heading:starvector + nav_heading:topvector).

        local v_color_r is min(1,max(0,-(nav_vel - vel)/100 )).
        local v_color_g is min(1,max(0,1-abs(nav_vel - vel)/100 )).
        local v_color_b is min(1,max(0,(nav_vel - vel)/100 )).

        set guide_tri_ll:color to RGB( min(1,max(0,(display_set/4)*sqrt(v_color_r))),
                                    min(1,max(0,(display_set/4)*sqrt(v_color_g))),
                                    min(1,max(0,(display_set/4)*sqrt(v_color_b)))).
        set guide_tri_lr:color to guide_tri_ll:color.
        set guide_tri_tl:color to guide_tri_ll:color.
        set guide_tri_tr:color to guide_tri_ll:color.

        set guide_tri_ll:show to true.
        set guide_tri_lr:show to true.
        set guide_tri_tl:show to true.
        set guide_tri_tr:show to true.
    }
    else
    {
        set guide_tri_ll:show to false.
        set guide_tri_lr:show to false.
        set guide_tri_tl:show to false.
        set guide_tri_tr:show to false.
        return.
    }
}

// draw a hud elevation ladder
local ladder_init_draw is false.
local ladder_vec_list is list().
local function ladder_vec_draw {

    local ladder_far is 300.
    local ladder_width is 0.25.
    local ladder_scale is 1.0.

    if not ladder_init_draw {
        if not (DEFINED UTIL_HUD_LADDER) {
            return.
        }
        set ladder_init_draw to true.

        for i in range(0,3) {
            ladder_vec_list:add(list( list(
                vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", ladder_scale, true, ladder_width, FALSE ),
                vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", ladder_scale, true, ladder_width, FALSE ) ),
                0.0) ).
        }

        for bar in ladder_vec_list {
            for bar_vec in bar[0] {
                set bar_vec:wiping to false.

            }
        }
    }
    if is_active_vessel() and display_set > 0 and not MAPVIEW and vel > 1.0 {

        local closest_pitch is sat(
            round(vel_pitch/UTIL_HUD_PITCH_DIV)*UTIL_HUD_PITCH_DIV,
            90-UTIL_HUD_PITCH_DIV-1).
        set ladder_vec_list[0][1] to closest_pitch+UTIL_HUD_PITCH_DIV.
        set ladder_vec_list[1][1] to closest_pitch.
        set ladder_vec_list[2][1] to closest_pitch-UTIL_HUD_PITCH_DIV.

        local camera_offset is camera_offset_vec.


        local set_color is RGB(0,min(display_set/4,1),0).

        for bar in ladder_vec_list {
            local cur_HEAD is heading(vel_bear, bar[1]).

            if bar[1] = 0 {
                set bar[0][0]:start to camera_offset+ladder_far*cur_HEAD:vector-ladder_far*sin(1.0)*cur_HEAD:starvector.
                set bar[0][1]:start to camera_offset+ladder_far*cur_HEAD:vector+ladder_far*sin(1.0)*cur_HEAD:starvector.
                
                set bar[0][0]:vec to -ladder_far*sin(5.0)*cur_HEAD:starvector.
                set bar[0][1]:vec to +ladder_far*sin(5.0)*cur_HEAD:starvector.
                set bar[0][0]:label to "".
            } else {
                set bar[0][0]:start to camera_offset+ladder_far*cur_HEAD:vector.
                set bar[0][1]:start to camera_offset+ladder_far*cur_HEAD:vector.

                set bar[0][0]:vec to -ladder_far*(sin(2.0)*cur_HEAD:starvector-sign(bar[1])*sin(0.5)*cur_HEAD:topvector ).
                set bar[0][1]:vec to ladder_far*(sin(2.0)*cur_HEAD:starvector+sign(bar[1])*sin(0.5)*cur_HEAD:topvector ).
                set bar[0][0]:label to ""+round_dec(bar[1],1).
            }
            set bar[0][0]:color to set_color.
            set bar[0][1]:color to set_color.
            set bar[0][0]:show to true.
            set bar[0][1]:show to true.
        }
    } else {
        for bar in ladder_vec_list {
            for bar_vec in bar[0] {
                set bar_vec:show to false.
            }
        }
    }
}


// draw a landing guidance marker
local land_init_draw is false.
local land_vert is 0.
local land_hori is 0.
local function land_vecdraw {
    local far is 300.
    local width is 0.25.
    local scale is 1.0.


    if not land_init_draw {
        if not (DEFINED UTIL_HUD_LAND_GUIDE) {
            return.
        }
        set land_init_draw to true.

        set land_vert to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", scale, true, width, FALSE ).
        set land_hori to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", scale, true, width, FALSE ).
        set land_vert:wiping to false.
        set land_hori:wiping to false.
    }

    if GEAR and is_active_vessel() and display_set > 0 and not MAPVIEW and vel > 1.0 {
        local set_color is RGB(0,min(display_set/4,1),0).
        local ghead is heading(UTIL_HUD_GHEAD + (choose 180 if vel_bear > 180 else 0),-UTIL_HUD_GSLOPE).
        local camera_offset is camera_offset_vec.

        set land_vert:start to camera_offset+far*(ghead:vector-0.1*ghead:topvector).
        set land_hori:start to camera_offset+far*(ghead:vector-0.1*ghead:starvector).

        set land_vert:vec to far*0.2*ghead:topvector.
        set land_hori:vec to far*0.2*ghead:starvector.

        set land_vert:color to set_color.
        set land_hori:color to set_color.

        local flare_alt is ship:altitude-ship:geoposition:terrainheight-UTIL_HUD_SHIP_HEIGHT.

        set land_hori:label to (choose "AGL "+round_dec(flare_alt,1)
                    if (flare_alt < UTIL_HUD_FLARE_ALT ) else "").

        set land_vert:show to true.
        set land_hori:show to true.
    } else {
        set land_vert:show to false.
        set land_hori:show to false.        
    }
}


local hud_info_init_draw is false.

local function lr_text_info {

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

        set hud_left_label:text to ""+
            ( choose ap_mode_get_str()+char(10) if AP_MODE_ENABLED else "") +
            " >> " + round(vel) +
            ( choose ap_nav_status_string()+char(10) if AP_NAV_ENABLED else char(10) ) +
            ( choose ap_flcs_rot_status_string()+char(10) if AP_FLCS_ROT_ENABLED else "") +
            hud_text_dict_left:values:join(char(10)).

        set hud_right_label:text to "" +
            round(100*THROTTLE)+
            ( choose util_shsys_status_string()+char(10) if UTIL_SHSYS_ENABLED else "") +
            round_dec(SHIP:ALTITUDE,0) +" <| " + display_status_strs[display_set] + char(10) +
            round_dec(vel_bear,0) +" -O " + char(10) +
            ( choose util_wp_status_string()+char(10) if UTIL_WP_ENABLED else "") +
            hud_text_dict_right:values:join(char(10)).

        if not hud_left:visible { hud_left:SHOW(). }
        if not hud_right:visible { hud_right:SHOW(). }

    }
    else {
        if hud_left:visible { hud_left:HIDE(). }
        if hud_right:visible { hud_right:HIDE(). }
    }
}

local control_part_vec_init_draw is false.
local control_part_vec is 0.
local function control_part_vec_draw {

    if not control_part_vec_init_draw {
        
        set control_part_vec TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", 1.0, true, 1.0, true ).
        //set control_part_vec:wiping to false.
        set control_part_vec_init_draw to true.
    }
    if is_active_vessel() and display_set = 5 and not MAPVIEW {

        set control_part_vec:vec to SHIP:CONTROLPART:position + UTIL_HUD_CAMERA_HEIGHT*ship:facing:topvector.
        set control_part_vec:show to true.
    } else {
        set control_part_vec:show to false.
    }
}


// main function of HUD
local hud_interval is 2.
local hud_i is 0.

function util_hud_info {
    set hud_i to hud_i+1.
    if hud_i = hud_interval {
        set hud_i to 0.
        lr_text_info().
    }
    land_vecdraw().
    ladder_vec_draw().
    nav_vecdraw().
    //control_part_vec_draw(). // for calibration
}

// add text to left
function util_hud_push_left {
    parameter key.
    parameter val.
    if hud_text_dict_left:haskey(key) {
        set hud_text_dict_left[key] to val.
    } else {
        hud_text_dict_left:add(key,val).
    }   
}

// add text to right
function util_hud_push_right {
    parameter key.
    parameter val.
    if hud_text_dict_right:haskey(key) {
        set hud_text_dict_right[key] to val.
    } else {
        hud_text_dict_right:add(key,val).
    }   
}

// remove text from left
function util_hud_pop_left {
    parameter key.
    if hud_text_dict_left:haskey(key) {
        hud_text_dict_left:remove(key).
    }
}

// remove text from right
function util_hud_pop_right {
    parameter key.
    if hud_text_dict_right:haskey(key) {
        hud_text_dict_right:remove(key).
    }
}


// RX SECTION

// shbus_rx compatible receive message
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
