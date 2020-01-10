
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

local text_bright is 1.0.

local MAIN_ENGINES is get_engines(main_engine_name).

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


        //set hud_right_lbutton to hud_right:ADDBUTTON("").
        //set hud_right_lbutton:style:BG to "blank_tex".
        //set hud_right_lbutton:style:textcolor to RGB(0,1,0).
        //set hud_right_lbutton:style:border:h to 0.
        //set hud_right_lbutton:style:margin:h to 0.
        //set hud_right_lbutton:style:padding:h to 0.
        ////set hud_right_lbutton:x to 10.
        //set hud_right_lbutton:style:width to 15.
        ////set hud_right_lbutton:style:ALIGN to "RIGHT".
        ////set hud_right_lbutton:style:border to 0.

        //set hud_right_lbutton:onclick to {
        //    set text_bright to text_bright + 0.25.
        //    if text_bright > 1.0 {
        //        set text_bright to 0.0.
        //    }
        //    set hud_left_label:style:textcolor to RGB(0,text_bright,0).
        //    set hud_right_label:style:textcolor to RGB(0,text_bright,0).
        //    set hud_right_lbutton:style:textcolor to RGB(0,text_bright,0).
        //    set hud_right_dbutton:style:textcolor to RGB(0,text_bright,0).
        //    set hud_right_lbutton:pressed to false.
        //}.

        //set hud_right_dbutton to hud_right:ADDBUTTON("").
        //set hud_right_dbutton:style:BG to "blank_tex".
        //set hud_right_dbutton:style:textcolor to RGB(0,1,0).
        //set hud_right_dbutton:style:border:h to 0.
        //set hud_right_dbutton:style:margin:h to 0.
        //set hud_right_dbutton:style:padding:h to 0.
        ////set hud_right_dbutton:x to 10.
        //set hud_right_dbutton:style:width to 15.
        ////set hud_right_dbutton:style:ALIGN to "RIGHT".
        ////set hud_right_dbutton:style:border to 0.

        //set hud_right_dbutton:onclick to {

        //    set hud_left:draggable to not hud_left:draggable.
        //    set hud_right:draggable to not hud_right:draggable.
        //}.


        set hud_right:visible to false.

        set v_set_prev to 0.

    }

    if not MAPVIEW and AG and is_active_vessel() {

        local stat_list is list().
        for me in MAIN_ENGINES {
            if me:multimode {
                stat_list:add(me:mode[0]).
            }
        }
        if GEAR {
            stat_list:add("G").
        }
        if BRAKES {
            stat_list:add("B").
        }
        if LIGHTS {
            stat_list:add("L").
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

        set hud_right_label:text to "" +
            //round_dec(100*SHIP:CONTROL:MAINTHROTTLE,0)+
            round_dec(100*THROTTLE,0)+
            stat_list:join("") +char(10) +
            round_dec(SHIP:ALTITUDE,0) + char(10) +
            eta_str + char(10) +
            tar_str +
            hud_text_dict_right:values:join(char(10)).

        if not hud_right:visible { hud_right:SHOW(). }

    }
    else {
        if hud_left:visible { hud_left:HIDE(). }
        if hud_right:visible { hud_right:HIDE(). }
    }
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
        print "could not decode hud rx msg".
        return false.
    }
    return true.
}

// RX SECTION END
