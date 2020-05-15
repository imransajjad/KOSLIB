
GLOBAL UTIL_HUD_ENABLED IS true.

IF NOT (DEFINED AP_FLCS_ROT_ENABLED) { GLOBAL AP_FLCS_ROT_ENABLED IS false.}
IF NOT (DEFINED AP_MODE_ENABLED) { GLOBAL AP_MODE_ENABLED IS false.}
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}
IF NOT (DEFINED UTIL_SHSYS_ENABLED) { GLOBAL UTIL_SHSYS_ENABLED IS false.}

local PARAM is readJson("1:/param.json")["UTIL_HUD"].

local ON_START is (choose PARAM["ON_START"] if PARAM:haskey("ON_START") else false).
local CAMERA_HEIGHT is (choose PARAM["CAMERA_HEIGHT"] if PARAM:haskey("CAMERA_HEIGHT") else 0).
local CAMERA_RIGHT is (choose PARAM["CAMERA_RIGHT"] if PARAM:haskey("CAMERA_RIGHT") else 0).

local GSLOPE is (choose PARAM["GSLOPE"] if PARAM:haskey("GSLOPE") else -2.5).
local GHEAD is (choose PARAM["GHEAD"] if PARAM:haskey("GHEAD") else 90.4).
local PITCH_DIV is (choose PARAM["PITCH_DIV"] if PARAM:haskey("PITCH_DIV") else 5).
local FLARE_ALT is (choose PARAM["FLARE_ALT"] if PARAM:haskey("FLARE_ALT") else 20).
local SHIP_HEIGHT is (choose PARAM["SHIP_HEIGHT"] if PARAM:haskey("SHIP_HEIGHT") else 2).

CLEARVECDRAWS().

local hud_text_dict_left is lexicon().
local hud_text_dict_right is lexicon().

local hud_setting_dict is lexicon("on", false, "green", true, "ladder", true, "land", true, "nav", true, "movable", false).

local hud_far is 30.0.
local hud_color is RGB(0,1,0).
local hud_land_slope is -2.5.
local hud_land_head is 90.4.

local lock camera_offset_vec to SHIP:CONTROLPART:position + 
    CAMERA_HEIGHT*ship:facing:topvector + 
    CAMERA_RIGHT*ship:facing:starvector.

// draw a vector on the ap_nav desired heading
local nav_init_draw is false.
local guide_tri_ll is 0.
local guide_tri_lr is 0.
local guide_tri_tl is 0.
local guide_tri_tr is 0.
local function nav_vecdraw {
    local guide_far is hud_far.
    local guide_width is 0.05.
    local guide_scale is 1.0.
    local guide_size is guide_far*sin(0.5).

    if not nav_init_draw {
        IF not (DEFINED AP_NAV_ENABLED) or not (AP_NAV_ENABLED) {
            return.
        }

        set nav_init_draw to true.

        set guide_tri_ll TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", guide_scale, true, guide_width, FALSE ).
        set guide_tri_lr TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", guide_scale, true, guide_width, FALSE ).

        set guide_tri_tl TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", guide_scale, true, guide_width, FALSE ).
        set guide_tri_tr TO VECDRAW(V(0,0,0), V(0,0,0), RGB(0,1.0,0),
            "", guide_scale, true, guide_width, FALSE ).


        set guide_tri_ll:wiping to false.
        set guide_tri_lr:wiping to false.
        set guide_tri_tl:wiping to false.
        set guide_tri_tr:wiping to false.

    }
    if hud_setting_dict["on"] and hud_setting_dict["nav"] and is_active_vessel() and not MAPVIEW and 
       (( DEFINED UTIL_WP_ENABLED and util_wp_queue_length() > 0 ) or
        ( DEFINED AP_MODE_ENABLED and DEFINED AP_NAV_ENABLED and AP_MODE_NAV)){

        local nav_heading is ap_nav_get_direction().
        local nav_vel_error is sat(ap_nav_get_vel()-vel,10)/10.
        local camera_offset is camera_offset_vec.

        set guide_tri_ll:start to camera_offset+guide_far*nav_heading:vector-guide_size*nav_heading:starvector.
        set guide_tri_ll:vec to guide_size*((1-nav_vel_error)*nav_heading:starvector - nav_heading:topvector).

        set guide_tri_lr:start to camera_offset+guide_far*nav_heading:vector+guide_size*nav_heading:starvector.
        set guide_tri_lr:vec to guide_size*(-(1-nav_vel_error)*nav_heading:starvector - nav_heading:topvector).


        set guide_tri_ll:color to hud_color.
        set guide_tri_lr:color to hud_color.

        set guide_tri_ll:show to true.
        set guide_tri_lr:show to true.

        if (nav_heading:vector*ship:facing:vector > 0.966) {
            set guide_tri_tl:start to camera_offset+guide_far*nav_heading:vector-guide_size*nav_heading:starvector.
            set guide_tri_tl:vec to guide_size*(nav_heading:starvector + nav_heading:topvector).

            set guide_tri_tr:start to camera_offset+guide_far*nav_heading:vector+guide_size*nav_heading:starvector.
            set guide_tri_tr:vec to guide_size*(-nav_heading:starvector + nav_heading:topvector).

            set guide_tri_tl:color to hud_color.
            set guide_tri_tr:color to hud_color.

            set guide_tri_tl:show to true.
            set guide_tri_tr:show to true.
        } else {
            set guide_tri_tl:start to camera_offset+guide_far*(ship:facing:vector).
            set guide_tri_tl:vec to camera_offset+guide_far*(nav_heading:vector-ship:facing:vector).
            
            set guide_tri_tl:color to hud_color.
            set guide_tri_tl:show to true.
            set guide_tri_tr:show to false.
        }
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
    local ladder_size is ladder_far*sin(5.0).

    if not ladder_init_draw {
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
    if hud_setting_dict["on"] and hud_setting_dict["ladder"] and is_active_vessel() and not MAPVIEW and vel > 1.0 {

        local closest_pitch is sat(
            round(vel_pitch/PITCH_DIV)*PITCH_DIV,
            90-PITCH_DIV-1).
        set ladder_vec_list[0][1] to closest_pitch+PITCH_DIV.
        set ladder_vec_list[1][1] to closest_pitch.
        set ladder_vec_list[2][1] to closest_pitch-PITCH_DIV.

        local camera_offset is camera_offset_vec.

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
            set bar[0][0]:color to hud_color.
            set bar[0][1]:color to hud_color.
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
local land_invis is 0.
local function land_vecdraw {
    local far is hud_far.
    local width is 0.025.
    local long is far/10.

    if not land_init_draw {

        set land_init_draw to true.
        set land_vert to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, width, FALSE ).
        set land_hori to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, width, FALSE ).
        set land_invis to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, 0.25, FALSE ).
        set land_vert:wiping to false.
        set land_hori:wiping to false.
    }

    if GEAR and is_active_vessel() and hud_setting_dict["on"] and hud_setting_dict["land"] and not MAPVIEW and vel > 1.0 {
        local camera_offset is camera_offset_vec.
        local ghead to heading(hud_land_head,hud_land_slope).

        set land_vert:start to camera_offset+far*ghead:vector-long*ghead:topvector.
        set land_hori:start to camera_offset+far*ghead:vector-long*ghead:starvector.
        set land_invis:start to camera_offset+far*ghead:vector
                            +0.5*long*ghead:starvector+0.1*long*ghead:topvector.

        set land_vert:vec to 2*long*ghead:topvector.
        set land_hori:vec to 2*long*ghead:starvector.
        set land_invis:vec to V(0,0,0).

        set land_vert:color to hud_color.
        set land_hori:color to hud_color.
        set land_invis:color to hud_color.

        local ground_alt is ship:altitude-max(ship:geoposition:terrainheight,0)-SHIP_HEIGHT.

        set land_invis:label to (choose "AGL "+round_dec(ground_alt,1)
                    if (ground_alt < FLARE_ALT ) else "").

        set land_vert:show to true.
        set land_hori:show to true.
        set land_invis:show to true.
    } else {
        set land_vert:show to false.
        set land_hori:show to false.
        set land_invis:show to false.
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
        set hud_left_label:style:textcolor to hud_color.

        set hud_left:visible to false.

        set hud_right to GUI(101,150).
        set hud_right:draggable to false.
        set hud_right:x to 960+150.
        set hud_right:style:BG to "blank_tex".

        set hud_right_label to hud_right:ADDLABEL("").
        set hud_right_label:style:ALIGN to "RIGHT".
        set hud_right_label:style:textcolor to hud_color.

        set hud_right:visible to false.

    }

    if hud_setting_dict["on"] and not MAPVIEW and is_active_vessel() {

        local vel_displayed is 0.
        local vel_type is "  ".
        if (NAVMODE = "ORBIT") {
            set vel_displayed to ship:velocity:orbit:mag.
            set vel_type to "  ".
        } else if (NAVMODE = "SURFACE") {
            set vel_displayed to ship:velocity:surface:mag.
            set vel_type to " >".
        } else if (NAVMODE = "TARGET") and HASTARGET {
            set vel_displayed to (TARGET:velocity:orbit-ship:velocity:orbit):mag.
            set vel_type to " +".
        }

        if hud_setting_dict["movable"] {
            set hud_left:draggable to true.
            set hud_right:draggable to true.
        } else {
            set hud_left:draggable to false.
            set hud_right:draggable to false.
        }

        set hud_left_label:text to ""+
            ( choose ap_mode_get_str()+char(10) if AP_MODE_ENABLED else "") +
            vel_type+"> " + round(vel_displayed) +
            ( choose ap_nav_status_string()+char(10) if AP_NAV_ENABLED else char(10) ) +
            ( choose ap_flcs_rot_status_string()+char(10) if AP_FLCS_ROT_ENABLED else "") +
            hud_text_dict_left:values:join(char(10)).

        set hud_right_label:text to "" +
            round(100*THROTTLE)+
            ( choose util_shsys_status_string()+char(10) if UTIL_SHSYS_ENABLED else "") +
            round_dec(SHIP:ALTITUDE,0) +" <| " + char(10) +
            round_dec(vel_bear,0) +" -O " + char(10) +
            ( choose util_wp_status_string()+char(10) if UTIL_WP_ENABLED else "") +
            hud_text_dict_right:values:join(char(10)).

        set hud_left_label:style:textcolor to hud_color.
        set hud_right_label:style:textcolor to hud_color.

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
        
        set control_part_vec TO VECDRAW(V(0,0,0), V(0,0,0), RGB(1.0,1.0,1.0),
            "", 1.0, true, 1.0, true ).
        //set control_part_vec:wiping to false.
        set control_part_vec_init_draw to true.
    }
    if is_active_vessel() and hud_setting_dict["on"] and not MAPVIEW {

        set control_part_vec:vec to SHIP:CONTROLPART:position + CAMERA_HEIGHT*ship:facing:topvector.
        set control_part_vec:show to true.
    } else {
        set control_part_vec:show to false.
    }
}


// main function of HUD
function util_hud_init {
    set hud_land_head to GHEAD.
    set hud_land_slope to -abs(GSLOPE).
    set hud_setting_dict["on"] to ON_START.
}

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

// shbus_tx compatible send messages
// TX_SECTION

function util_hud_get_help_str {
    return list(
        " ",
        "UTIL_HUD running on "+core:tag,
        "hudland(gslope,bear) set landing",
        "hudsw [setting] toggle setting",
        "    on",
        "    green",
        "    ladder",
        "    land",
        "    nav",
        "    movable"
        ).
}

function util_hud_parse_command {
    parameter commtext.
    parameter args is -1.

    if commtext:startswith("hud") {
        if not (args = -1) and args:length = 0 {
            print "hud args expected but empty".
            return true.
        }
    } else {
        return false.
    }

    if commtext:startswith("hudsw") {
        local newkey is args.
        util_shbus_tx_msg("HUD_SETTING_TOGGLE", list(newkey)).
    } else if commtext:startswith("hudland(") {
        if args:length = 2 {
            util_shbus_tx_msg("HUD_LAND_SET", args).
        } else {
            print "use args (pitch,bear)".
        }
    } else {
        return false.
    }
    return true.
}

// TX_SECTION END


// RX SECTION

// shbus_rx compatible receive message
function util_hud_decode_rx_msg {
    parameter sender.
    parameter opcode.
    parameter data.

    if not opcode:startswith("HUD") {
        return.
    }
    
    if opcode = "HUD_PUSHL" {
        util_hud_push_left(data[0],data[1]).
    } else if opcode = "HUD_PUSHR" {
        util_hud_push_right(data[0],data[1]).
    } else if opcode = "HUD_POPL" {
        hud_text_dict_left:remove(data[0]).
    } else if opcode = "HUD_POPR" {
        hud_text_dict_right:remove(data[0]).
    } else if opcode = "HUD_SETTING_TOGGLE" {
        if data[0] = "off" {set data[0] to "on".}
        if hud_setting_dict:haskey(data[0]) {
            set hud_setting_dict[data[0]] to (not hud_setting_dict[data[0]]).
            set hud_color to RGB( 0, (choose 1 if hud_setting_dict["green"] else 0), 0 ).
        } else {
            util_shbus_tx_msg("ACK", list("util hud setting not found"), list(sender)).

        }
    } else if opcode = "HUD_LAND_SET" {
        set hud_land_head to data[1].
        set hud_land_slope to -abs(data[0]).
    } else {
        util_shbus_tx_msg("ACK", list("could not decode hud rx msg"), list(sender)).
        print "could not decode hud rx msg".
        return false.
    }
    return true.
}

// RX SECTION END

