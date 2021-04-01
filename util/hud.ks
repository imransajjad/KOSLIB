
GLOBAL UTIL_HUD_ENABLED IS true.

local SETTINGS is get_param(readJson("param.json"),"UTIL_HUD", lexicon()).

local CAMERA_HEIGHT is get_param(SETTINGS, "CAMERA_HEIGHT", 0).
local CAMERA_RIGHT is get_param(SETTINGS, "CAMERA_RIGHT", 0).

local HUD_COLOR is RGB(
        get_param(SETTINGS, "COLOR_R", 0),
        get_param(SETTINGS, "COLOR_G", 1),
        get_param(SETTINGS, "COLOR_B", 0)).

local PITCH_DIV is get_param(SETTINGS, "PITCH_DIV", 5).
local FLARE_ALT is get_param(SETTINGS, "FLARE_ALT", 20).
local SHIP_HEIGHT is get_param(SETTINGS, "SHIP_HEIGHT", 2).

local PARAM_NAV is get_param(readJson("param.json"),"AP_NAV", lexicon()).
if PARAM_NAV:haskey("GEAR_HEIGHT") {
    set SHIP_HEIGHT to get_param(PARAM_NAV, "GEAR_HEIGHT", 2).
}

CLEARVECDRAWS().

local hud_text_dict_left is lexicon().
local hud_text_dict_right is lexicon().

set SETTINGS["on"] to get_param(SETTINGS, "ON_START", false).
set SETTINGS["ladder"] to get_param(SETTINGS, "LADDER_START", false).
set SETTINGS["nav"] to get_param(SETTINGS, "NAV_START", false).
set SETTINGS["alpha"] to false.
set SETTINGS["ALPHA_DEG"] to 7.5.
set SETTINGS["align"] to false.
set SETTINGS["ALIGN_ELEV"] to -2.5.
set SETTINGS["ALIGN_HEAD"] to 90.4.
set SETTINGS["ALIGN_ROLL"] to 0.
set SETTINGS["movable"] to false.

if exists("hud-settings.json") {
    local PREV_SETTINGS is readJson("hud-settings.json").
    for key in PREV_SETTINGS:keys {
        set SETTINGS[key] to PREV_SETTINGS[key].
    }
    set CAMERA_HEIGHT to SETTINGS["CAMERA_HEIGHT"].
    set CAMERA_RIGHT to SETTINGS["CAMERA_RIGHT"].
    set HUD_COLOR to SETTINGS["HUD_COLOR"].
}

local function hud_settings_save {
    set SETTINGS["CAMERA_HEIGHT"] to CAMERA_HEIGHT.
    set SETTINGS["CAMERA_RIGHT"] to CAMERA_RIGHT.
    set SETTINGS["HUD_COLOR"] to HUD_COLOR.
    
    writeJson(SETTINGS, "hud-settings.json").
}

local hud_far is 30.0.

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
        if not (defined AP_NAV_ENABLED) {
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
    local nav_vel is ap_nav_get_hud_vel().

    if SETTINGS["on"] and SETTINGS["nav"] and ISACTIVEVESSEL
        and not MAPVIEW and nav_vel:mag > 0.3  {

        local py_temp is pitch_yaw_from_dir(nav_vel:direction).
        local nav_heading is heading(py_temp[1],py_temp[0]).
        local nav_vel_error is sat(ap_nav_get_vel_err_mag(),10)/10.
        local camera_offset is camera_offset_vec.

        set guide_tri_ll:start to camera_offset+guide_far*nav_heading:vector-guide_size*nav_heading:starvector.
        set guide_tri_ll:vec to guide_size*((1-nav_vel_error)*nav_heading:starvector - nav_heading:topvector).

        set guide_tri_lr:start to camera_offset+guide_far*nav_heading:vector+guide_size*nav_heading:starvector.
        set guide_tri_lr:vec to guide_size*(-(1-nav_vel_error)*nav_heading:starvector - nav_heading:topvector).


        set guide_tri_ll:color to HUD_COLOR.
        set guide_tri_lr:color to HUD_COLOR.

        set guide_tri_ll:show to true.
        set guide_tri_lr:show to true.

        if (nav_heading:vector*ship:facing:vector > 0.966) {
            set guide_tri_tl:start to camera_offset+guide_far*nav_heading:vector-guide_size*nav_heading:starvector.
            set guide_tri_tl:vec to guide_size*(nav_heading:starvector + nav_heading:topvector).

            set guide_tri_tr:start to camera_offset+guide_far*nav_heading:vector+guide_size*nav_heading:starvector.
            set guide_tri_tr:vec to guide_size*(-nav_heading:starvector + nav_heading:topvector).

            set guide_tri_tl:color to HUD_COLOR.
            set guide_tri_tr:color to HUD_COLOR.

            set guide_tri_tl:show to true.
            set guide_tri_tr:show to true.
        } else {
            set guide_tri_tl:start to camera_offset+guide_far*(ship:facing:vector).
            set guide_tri_tl:vec to camera_offset+guide_far*(nav_heading:vector-ship:facing:vector).
            
            set guide_tri_tl:color to HUD_COLOR.
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
    if SETTINGS["on"] and SETTINGS["ladder"] and ISACTIVEVESSEL and not MAPVIEW and ship:airspeed > 1.0 {

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
            set bar[0][0]:color to HUD_COLOR.
            set bar[0][1]:color to HUD_COLOR.
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


// draw a alignment guidance marker
local align_init_draw is false.
local align_vert is 0.
local align_hori is 0.
local align_invis is 0.

local function align_marker_draw {
    local far is hud_far.
    local width is 0.025.
    local long is far/10.

    if not align_init_draw {

        set align_init_draw to true.
        set align_vert to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, width, false ).
        set align_hori to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, width, false ).
        set align_invis to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, 0.25, false ).
        set align_vert:wiping to false.
        set align_hori:wiping to false.
    }

    if ISACTIVEVESSEL and SETTINGS["on"] and SETTINGS["align"] and not MAPVIEW {
        local camera_offset is camera_offset_vec.
        local ghead is heading(SETTINGS["ALIGN_HEAD"],SETTINGS["ALIGN_ELEV"],-SETTINGS["ALIGN_ROLL"]).
        
        if HASTARGET {
            local target_ship is TARGET.
            set ghead to target_ship:facing.
            if not target_ship:hassuffix("velocity") {
                set ghead to ghead*R(180,0,0).
            }
        }

        set align_vert:start to camera_offset+far*ghead:vector-long*ghead:topvector.
        set align_hori:start to camera_offset+far*ghead:vector-long*ghead:starvector.
        set align_invis:start to camera_offset+far*ghead:vector
                            +0.5*long*ghead:starvector+0.1*long*ghead:topvector.

        set align_vert:vec to 2*long*ghead:topvector.
        set align_hori:vec to 2*long*ghead:starvector.
        set align_invis:vec to V(0,0,0).

        set align_vert:color to HUD_COLOR.
        set align_hori:color to HUD_COLOR.
        set align_invis:color to HUD_COLOR.

        local ground_alt is ship:altitude-max(ship:geoposition:terrainheight,0)-SHIP_HEIGHT.

        set align_invis:label to (choose "AGL "+round_dec(ground_alt,1)
                    if (ground_alt < FLARE_ALT ) else "").

        set align_vert:show to true.
        set align_hori:show to true.
        set align_invis:show to true.
    } else {
        set align_vert:show to false.
        set align_hori:show to false.
        set align_invis:show to false.
    }
}

local alpha_bracket_init_draw is false.
local alpha_bracket_vec is 0.
local function alpha_bracket_draw {
    local far is hud_far.
    local width is 0.025.
    local long is far/10.

    if not alpha_bracket_init_draw {
        set alpha_bracket_init_draw to true.
        set alpha_bracket_vec to vecdraw(V(0,0,0), V(0,0,0), RGB(0,1,0),
            "", 1.0, true, width, FALSE ).
        set alpha_bracket_vec:wiping to false.
    }

    if ISACTIVEVESSEL and SETTINGS["on"] and SETTINGS["alpha"] and not MAPVIEW {
        local camera_offset is camera_offset_vec.

        local alpha_vec is angleaxis(-SETTINGS["ALPHA_DEG"],ship:facing:starvector)*ship:srfprograde:vector.
        set alpha_bracket_vec:start to camera_offset+far*alpha_vec.
        set alpha_bracket_vec:vec to 0.5*long*ship:facing:starvector.
        
        set alpha_bracket_vec:color to HUD_COLOR.
        set alpha_bracket_vec:show to true.
    } else {
        set alpha_bracket_vec:show to false.
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
        set hud_left_label:style:textcolor to HUD_COLOR.

        set hud_left:visible to false.

        set hud_right to GUI(101,150).
        set hud_right:draggable to false.
        set hud_right:x to 960+150.
        set hud_right:style:BG to "blank_tex".

        set hud_right_label to hud_right:ADDLABEL("").
        set hud_right_label:style:ALIGN to "RIGHT".
        set hud_right_label:style:textcolor to HUD_COLOR.

        set hud_right:visible to false.

    }

    if SETTINGS["on"] and not MAPVIEW and ISACTIVEVESSEL {

        local vel_displayed is "".
        local alt_head_str is "".

        if (NAVMODE = "ORBIT") {
            set vel_displayed to "> " + round_dec(round_fig(ship:velocity:orbit:mag,2),2).
            if ship:orbit:eccentricity < 1.0 {
                if ship:orbit:trueanomaly >= 90 and ship:orbit:trueanomaly < 270{
                    local time_hud is eta:apoapsis - (choose 0 if ship:orbit:trueanomaly < 180 else ship:orbit:period).
                    set alt_head_str to "Ap "+round(ship:orbit:apoapsis) +
                        char(10)+ " T " + round_fig(-time_hud,1)+"s".
                } else {
                    local time_hud is eta:periapsis - (choose 0 if ship:orbit:trueanomaly > 180 else ship:orbit:period).
                    set alt_head_str to "Pe "+round(ship:orbit:periapsis) +
                        char(10)+ " T " + round_fig(-time_hud,1)+"s".
                }
            } else {
                if ship:orbit:hasnextpatch and ship:orbit:trueanomaly >= 0 {
                    set alt_head_str to "Esc " +
                        char(10)+ " T " + round(ship:orbit:nextpatcheta)+"s".
                } else{
                    set alt_head_str to "Pe "+round(ship:orbit:periapsis) +
                        char(10)+ " T " + round(eta:periapsis)+"s".
                }
            }
            set alt_head_str to alt_head_str + char(10) + "e " +  + round_fig(ship:orbit:eccentricity,2).
        } else if (NAVMODE = "SURFACE") {
            set vel_displayed to ">> " + round_dec(round_fig(ship:velocity:surface:mag,2),2).
            
            local ground_alt is ship:altitude-max(ship:geoposition:terrainheight,0)-SHIP_HEIGHT.
            set alt_head_str to (choose round_dec(ground_alt,1) +" ^_"
                    if (ground_alt < FLARE_ALT ) else round_dec(SHIP:ALTITUDE,0)+" <|" ) +
                    char(10) + round_dec(vel_bear,0) +" -O ".
        } else if (NAVMODE = "TARGET") and HASTARGET {
            local target_ship is TARGET.
            if not TARGET:hassuffix("velocity") {
                set target_ship to TARGET:ship.
            }
            set vel_displayed to "+> " + round_dec(round_fig((target_ship:velocity:orbit-ship:velocity:orbit):mag,2),2).
            set alt_head_str to round_dec(round_fig((target_ship:position):mag,2),2) + "+|".
        }

        if SETTINGS["movable"] {
            set hud_left:draggable to true.
            set hud_right:draggable to true.
        } else {
            set hud_left:draggable to false.
            set hud_right:draggable to false.
        }

        // no status string should have a char(10) or newline as the first
        // or last character
        set hud_left_label:text to ""+
            ( choose ap_mode_get_str()+char(10) if defined AP_MODE_ENABLED else "") +
            ( vel_displayed ) + ( choose ap_nav_status_string()+char(10) if defined AP_NAV_ENABLED else char(10) ) +
            ( choose ap_orb_status_string()+char(10) if defined AP_ORB_ENABLED else "") +
            ( choose ap_aero_w_status_string()+char(10) if defined AP_AERO_W_ENABLED else "") +
            hud_text_dict_left:values:join(char(10)).

        set hud_right_label:text to "" +
            round(100*THROTTLE)+
            ( choose util_shsys_status_string()+char(10) if defined UTIL_SHSYS_ENABLED else "") +
            alt_head_str+char(10) +
            ( choose util_wp_status_string()+char(10) if defined UTIL_WP_ENABLED else "") +
            hud_text_dict_right:values:join(char(10)).

        set hud_left_label:style:textcolor to HUD_COLOR.
        set hud_right_label:style:textcolor to HUD_COLOR.

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
    if ISACTIVEVESSEL and SETTINGS["on"] and not MAPVIEW {

        set control_part_vec:vec to SHIP:CONTROLPART:position + CAMERA_HEIGHT*ship:facing:topvector.
        set control_part_vec:show to true.
    } else {
        set control_part_vec:show to false.
    }
}

local hud_interval is 2.
local hud_i is 0.
function util_hud_info {
    set hud_i to hud_i+1.
    if hud_i = hud_interval {
        set hud_i to 0.
        lr_text_info().
    }
    align_marker_draw().
    ladder_vec_draw().
    nav_vecdraw().
    alpha_bracket_draw().
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

// set key to value in setting dictionary
// if value not given, toggle
function util_hud_setting {
    parameter key.
    parameter value.

    if SETTINGS:haskey(key) {
        if SETTINGS[key]:typename = value:typename {
            set SETTINGS[key] to value.
        } else {
            print "cannot set " + value.
            return false.
        }
        return true.
    }
    return false.
}

// clear the hud temporarily, but don't change any settings
// i.e. next time util_hud_info is called, it will work the same
function util_hud_clear {
    local saved_setting is SETTINGS["on"].
    set SETTINGS["on"] to false.
    util_hud_info().
    set SETTINGS["on"] to saved_setting.
}

// shbus_tx compatible send messages
// TX_SECTION

function util_hud_get_help_str {
    return list(
        "UTIL_HUD running on "+core:tag,
        "hud align(elev,bear,roll)  set align",
        "hud color(r,g,b)   set HUD_COLOR",
        "hud cam(top,star)  move hud position",
        "hud alpha(deg)     alpha marker",
        "hud reset          remove stored changes",
        "hud [on/off]       turn hud on or off",
        "hud [setting] [on/off] set setting",
        "     ladder",
        "     alpha",
        "     align",
        "     nav",
        "     movable",
        "hud help           print help"
        ).
}

function util_hud_parse_command {
    parameter commtext.
    parameter args is list().

    if commtext:startswith("hud ") {
        set commtext to commtext:remove(0,4).
    } else {
        return false.
    }

    if commtext:endswith("on") or commtext:endswith("off") {
        local words is commtext:split(" ").
        if words:length > 2 {
            print "usage: hud [setting] [on/off] or hud [on/off]".
        } else {
            local key is (choose words[0] if words:length = 2 else "on").
            util_shbus_tx_msg("HUD_SETTING_SET", list(key, commtext:endswith("on") ) ).
        }
    } else if commtext = "align" and all_scalar(args) {
        if (args:length = 0 or args:length = 2 or args:length = 3) {
            if args:length = 2 { args:add(0). }
            util_shbus_tx_msg("HUD_ALIGN_SET", args).
        } else {
            print "use args (pitch,bear) or (pitch,bear,roll) or no args (off)".
        }
    } else if commtext = "color" and all_scalar(args) {
        if (args:length = 3) {
            util_shbus_tx_msg("HUD_COLOR_SET", args).
        } else {
            print "use args (r,g,b) <- [0,1]".
        }
    } else if commtext = "cam" and all_scalar(args) {
        if (args:length = 2) {
            util_shbus_tx_msg("HUD_CAM_MOVE", args).
        } else {
            print "use args (top,star)".
        }
    } else if commtext = "alpha" and all_scalar(args) {
        if (args:length = 0) or (args:length = 1) {
            util_shbus_tx_msg("HUD_ALPHA_SET", args).
        } else {
            print "use args (deg)".
        }
    } else if commtext = "reset" {
        util_shbus_tx_msg("HUD_RESET",args).
    } else if commtext = "help" {
        util_term_parse_command("help HUD").
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
    parameter recipient.
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
    } else if opcode = "HUD_SETTING_SET" {
        if not util_hud_setting(data[0],data[1]) {
            util_shbus_ack("util hud setting not found", sender).
        } else {
            hud_settings_save().
        }
    } else if opcode = "HUD_COLOR_SET" {
        set HUD_COLOR to RGB(data[0],data[1],data[2]).
        hud_settings_save().
    } else if opcode = "HUD_ALIGN_SET" {
        if data:length = 0 {
            util_hud_setting("align",false).
        } else {
            util_hud_setting("align",true).
            util_hud_setting("ALIGN_ELEV",data[0]).
            util_hud_setting("ALIGN_HEAD",data[1]).
            util_hud_setting("ALIGN_ROLL",data[2]).
        }
        hud_settings_save().
    } else if opcode = "HUD_ALPHA_SET" {
        if data:length = 0 {
            util_hud_setting("alpha",false).
        } else {
            util_hud_setting("alpha",true).
            util_hud_setting("ALPHA_DEG",data[0]).
        }
        hud_settings_save().
    } else if opcode = "HUD_CAM_MOVE" {
        set CAMERA_HEIGHT to CAMERA_HEIGHT + data[0].
        set CAMERA_RIGHT to CAMERA_RIGHT + data[1].
        hud_settings_save().
    } else if opcode = "HUD_RESET" {
        if exists("hud-settings.json") {
            deletepath("hud-settings.json").
        } else {
            print "hud-settings.json not found".
        }
    } else {
        util_shbus_ack("could not decode hud rx msg", sender).
        print "could not decode hud rx msg".
        return false.
    }
    return true.
}

// RX SECTION END

