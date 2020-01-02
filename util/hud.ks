
GLOBAL UTIL_HUD_ENABLED IS true.

IF NOT (DEFINED AP_NAV_ENABLED) { GLOBAL AP_NAV_ENABLED IS false.}
IF NOT (DEFINED AP_MODE_ENABLED) { GLOBAL AP_MODE_ENABLED IS false.}
IF NOT (DEFINED UTIL_WP_ENABLED) { GLOBAL UTIL_WP_ENABLED IS false.}



local lock AG to AG3.


CLEARVECDRAWS().

local v_set_prev is 0.
local vec_info_timeout is 0.
local vec_info_init_draw is false.
local hud_info_init_draw is false.

local hud_text_dict_left is lexicon().
local hud_text_dict_right is lexicon().


FUNCTION vec_info_draw {
    SET vec_info_timeout TO 10.
}
FUNCTION util_hud_vec_info {

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
    IF MAPVIEW or vec_info_timeout <= 0  or vel < 1.0 {
        set vec_info_timeout TO 0.

        set guide_tri_l:show to false.
        set guide_tri_r:show to false.
        set guide_tri_b:show to false.
        return.
    } ELSE {
        set vec_info_timeout to vec_info_timeout -1.

        set nav_heading to ap_nav_get_direction().
        set nav_vel to ap_nav_get_vel().

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

        set guide_tri_l:color to RGB(sqrt(v_color_r),sqrt(v_color_g),sqrt(v_color_b)).
        set guide_tri_r:color to guide_tri_l:color.
        set guide_tri_b:color to guide_tri_l:color.

        set guide_tri_l:show to true.
        set guide_tri_r:show to true.
        set guide_tri_b:show to true.

    }
}

function util_hud_info {

    if not hud_info_init_draw {

        set hud_info_init_draw to true.


        set hud_left to GUI(101,100).
        set hud_left:draggable to false.
        set hud_left:x to 960-150-101.
        set hud_left:style:BG to "blank_tex".
        set hud_left_label to hud_left:ADDLABEL("").
        set hud_left_label:style:ALIGN to "LEFT".
        set hud_left_label:style:textcolor to RGB(0,1,0).

        set hud_left:visible to false.

        set hud_right to GUI(101,100).
        set hud_right:draggable to false.
        set hud_right:x to 960+150.
        set hud_right:style:BG to "blank_tex".
        set hud_right_label to hud_right:ADDLABEL("").
        set hud_right_label:style:ALIGN to "RIGHT".
        set hud_right_label:style:textcolor to RGB(0,1,0).

        set hud_right:visible to false.

        set v_set_prev to 0.

    }

    if not MAPVIEW and AG and is_active_vessel() {


        if not (MAIN_ENGINES:length = 0) {
            set engine_mode_str to MAIN_ENGINES[0]:mode[0].
        } else {
            set engine_mode_str to "".
        }

        local stat_list is list().
        local stat_str is "".
        if GEAR {
            stat_list:add("G").
        }
        if BRAKES {
            stat_list:add("B").
        }
        if LIGHTS {
            stat_list:add("L").
        }
        if stat_list:length > 0 {
            set stat_str to stat_list:join("/").
        }

        local vs_string is "".
        if UTIL_WP_ENABLED and AP_NAV_ENABLED and AP_MODE_ENABLED {
            local WPL is util_wp_queue_length().

            if WPL > 0 or AP_NAV_CHECK() {
                vec_info_draw().
            }
            if WPL > 0 {
                set eta_str to "WP" + WPL +" "+
                    round_dec(min(9999,ap_nav_get_distance()/max(vel,0.0001)),0)+"s".
            } else {
                set eta_str to "".
            }

            set nav_vel to ap_nav_get_vel().
            if AP_NAV_CHECK() or AP_VEL_CHECK() or WPL > 0 {
                if (v_set_prev < nav_vel){
                    set vs_string to "/" + round_dec(nav_vel,0) + "+".
                } else if (v_set_prev > nav_vel){
                    set vs_string to "/" + round_dec(nav_vel,0) + "-".
                } else {
                    set vs_string to "/" + round_dec(nav_vel,0).
                }
            } else {
                set vs_string to "".
            }
            set v_set_prev to nav_vel.
        }

        set hud_left_label:text to ap_mode_get_str() + char(10) +
            round_dec(vel,0) + vs_string + char(10) +
            round_dec(vel_pitch,2)+ char(10) +
            round_dec(vel_bear,2) + char(10) +
            hud_text_dict_left:values:join(char(10)).

        
        if not hud_left:visible { hud_left:SHOW(). }

        

        set hud_right_label:text to "" +
            //round_dec(100*SHIP:CONTROL:MAINTHROTTLE,0)+
            round_dec(100*THROTTLE,0)+
            engine_mode_str +char(10) +
            round_dec(SHIP:ALTITUDE,0) + char(10) +
            stat_str + char(10) +
            eta_str + char(10) +
            hud_text_dict_right:values:join(char(10)).

        if not hud_right:visible { hud_right:SHOW(). }

    }
    else {
        if hud_left:visible { hud_left:HIDE(). }
        if hud_right:visible { hud_right:HIDE(). }
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
        if hud_text_dict_left:haskey(data[0]) {
            set hud_text_dict_left[data[0]] to data[1].
        } else {
            hud_text_dict_left:add(data[0],data[1]).
        }
    } else if opcode = "HUD_PUSHR" {
        if hud_text_dict_right:haskey(data[0]) {
            set hud_text_dict_right[data[0]] to data[1].
        } else {
            hud_text_dict_right:add(data[0],data[1]).
        }
    } else if opcode = "HUD_POPL" {
        hud_text_dict_left:remove(data[0]).
    } else if opcode = "HUD_POPR" {
        hud_text_dict_right:remove(data[0]).
    } else {
        print "could not decode hud rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
