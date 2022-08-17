// util_common.ks

// a set of common utilities 

GLOBAL UTIL_COMMON_ENABLED is true.

set pi to 3.14159265359.
set DEG2RAD to pi/180.
set RAD2DEG to 180/pi.
set g0 to 9.806.

global lock ISACTIVEVESSEL to (kuniverse:activevessel = ship).

global BODY_navball_change_alt is lexicon("Kerbin", 36000, "Mun", 4000).

function sat {
    parameter X.
    parameter Lim is 1.0.
    if X > Lim { return Lim.}
    if X < -Lim { return -Lim.}
    return X.
}

function deadzone {
    parameter X.
    parameter BAND.
    if X > BAND { return X-BAND.}
    if X < -BAND { return X+BAND.}
    return 0.
}

function convex {
    parameter X.
    parameter Y.
    parameter e.
    return (1-e)*X + e*Y.
}

function sign {
    parameter x.
    if X > 0 { return 1.0.}
    if X < 0 { return -1.0.}
    return 0.
}

function abs_max {
    parameter x,y.
    if abs(x) > abs(y) {
        return x.
    } else {
        return y.
    }
}

function round_dec {
    parameter NUM.
    parameter FRAD_DIG.
    return ROUND(NUM*(10^FRAD_DIG))/(10^FRAD_DIG).
}
set rdc to round_dec@.

function round_fig {
    parameter NUM.
    parameter FIG.
    local FRAD_DIG is max(0,FIG-floor(log10(max(0.00001,abs(num))))-1).
    return ROUND(NUM*(10^FRAD_DIG))/(10^FRAD_DIG).
}
set rfg to round_fig@.

function list_print {
    parameter arg_in.
    LOCAL TOTAL_STRING is "".
    for e in arg_in{
        SET TOTAL_STRING TO TOTAL_STRING+e+ " ".
    }
    PRINT TOTAL_STRING.
}

function round_dec_list {
    parameter arg_in.
    parameter FRAD_DIG.
    local newlist is list().
    for e in arg_in{
        newlist:add(round_dec(e,FRAD_DIG)).
    }
    return newlist.
}

function round_vec {
    parameter vec_in.
    parameter FRAD_DIG.
    return "V(" + round_fig(vec_in:x,FRAD_DIG) + "," +
        round_fig(vec_in:y,FRAD_DIG) + "," +
        round_fig(vec_in:z,FRAD_DIG) + ")".
}

function all_scalar {
    parameter args.
    local allscalarargs is true.
    for i in args {
        if not (i:typename = "Scalar") {
            set allscalarargs to false.
            print "nonscalar arg: " + i.
            break.
        }
    }
    return allscalarargs.
}

function wrap_angle_until {
    parameter theta.
    UNTIL (theta < 180){
        SET theta TO theta-360.
    }
    UNTIL (theta >= -180){
        SET theta TO theta+360.
    }
    return theta.
}

function wrap_angle {
    parameter theta.
    parameter max_angle is 360.
    return wrap_angle_until(theta).
    // return remainder(theta+max_angle/2,max_angle)-max_angle/2.
}

function unit_vector {
    parameter vector_in.
    return (1.0/vector_in:mag)*vector_in.
}

function listsum {
    parameter L.
    LOCAL TOTAL IS 0.
    for e in L{
        SET TOTAL TO TOTAL+e.
    }
    return TOTAL.
}

function haversine {
    parameter lat0.
    parameter lng0.

    parameter lat1.
    parameter lng1.

    set dlong to -(lng1-lng0).

    set top to cos(lat0)*cos(dlong)*cos(lat1) + sin(lat0)*sin(lat1).
    set fore to sin(lat0)*cos(dlong)*cos(lat1) - cos(lat0)*sin(lat1).
    set left to sin(dlong)*cos(lat1).

    // list[0] is eject
    // list[1] is total angular difference
    return list(arctan2(-left,-fore) ,arccos(sat(top))).

}

function haversine_latlng {
    parameter lat0.
    parameter lng0.

    parameter eject.
    parameter total.

    local dir_temp is R(lat0-90,lng0,0)*R(90-total,180-eject,0).
    return list(dir_temp:pitch,dir_temp:yaw).
}

function haversine_dir {
    parameter dirf.

    local dir_temp is R(90,0,0)*dirf.
    local total is wrap_angle(90-dir_temp:pitch).
    local roll is dir_temp:roll.
    local eject is wrap_angle(dir_temp:yaw).
    return list( eject, total, roll ).
}

function dir_haversine {
    parameter have_list. // eject, total, roll
    return R(-90,0,0)*R(90-have_list[1],have_list[0],have_list[2]).
    // return R(-90,0,0)*R(0,have_list[0],0)*R(90-have_list[1],0,0)*R(0,0,have_list[2]).
    // return R(0,0,have_list[0])*R(have_list[1],0,0).
}

function haversine_vec {
    parameter frame.
    parameter v.

    local dir_temp is (R(90,0,0)*(-frame)*v):direction.
    local total is wrap_angle(90-dir_temp:pitch).
    local roll is dir_temp:roll.
    local eject is wrap_angle(-dir_temp:yaw).
    return list( eject, total ).
}

function vec_haversine {
    parameter frame.
    parameter have_list. // eject, total

    return frame*R(90,0,0)*R(0,have_list[0]-180,0)*R(have_list[1],0,0)*V(0,1,0).
}

function pitch_yaw_from_dir {
    parameter dir.
    local guide_dir_py to R(90,0,0)*(-SHIP:UP)*dir.
    return list( (mod(guide_dir_py:pitch+90,180)-90) ,
                 (360-guide_dir_py:yaw) ).
}

function srf_head_from_vec {
    parameter vec.
    local guide_dir_py to R(90,0,0)*(-SHIP:UP)*vec:direction.
    return heading(360-guide_dir_py:yaw, mod(guide_dir_py:pitch+90,180)-90, 0).
}

function vec_max {
    parameter va. // vector
    parameter vb. // vector
    set va:x to max(va:x,vb:x).
    set va:y to max(va:y,vb:y).
    set va:z to max(va:z,vb:z).
    return va.
}

function vec_min {
    parameter va. // vector
    parameter vb. // vector
    set va:x to min(va:x,vb:x).
    set va:y to min(va:y,vb:y).
    set va:z to min(va:z,vb:z).
    return va.
}

function vec_max_axis {
    parameter va. // vector
    if va:x > va:y and va:x > va:z {
        return V(va:x,0,0).
    } else if va:y > va:z {
        return V(0,va:y,0).
    } else {
        return V(0,0,va:z).
    }
}

function remainder {
    parameter x.
    parameter divisor.
    if x > 0 {
        return mod(x,divisor).
    } else {
        return mod(divisor+mod(x,divisor),divisor).
    }
}

function outerweight {
    parameter x.
    parameter xmin is 0.5.
    parameter xsat is 1.5.

    return sat(deadzone(abs(x),xmin)/(xsat-xmin),1.0).
}

function get_engines {
    parameter tag.
    local main_engine_list is LIST().
    if not (tag = "") {
        for e in SHIP:PARTSDUBBED(tag){
            main_engine_list:add(e).
        }
    } else {
        list Engines in main_engine_list.
    }
    return main_engine_list.
}

function get_parts_tagged {
    parameter tag.
    local tagged_list is LIST().
    if not (tag = "") {
        for e in SHIP:PARTSDUBBED(tag){
            tagged_list:add(e).
        }
    }
    if tagged_list:length > 0 {
        print "get_parts_tagged " + tag.
        for p in tagged_list {
            print p:name.
        }
    }
    return tagged_list.
}

function get_com_offset {
    return (-ship:facing)*(ship:position - ship:controlpart:position).
}

function string_acro {
    parameter strin.
    local strout is "".
    for substr in strin:split(" ") {
        set strout to strout+substr[0].
    }
    return strout.
}

function flush_core_messages {
    parameter ECHO is true.
    UNTIL CORE:MESSAGES:EMPTY {
        SET RECEIVED TO CORE:MESSAGES:POP.
        if ECHO {print RECEIVED:CONTENT.}
    }
}

function sign {
    parameter x.
    if (x > 0) {
        return +1.0.
    } else if (x < 0) {
        return -1.0.
    }
    return 0.0.
}

function get_param {
    parameter dict.
    parameter key.
    parameter default is 0.
    if dict:haskey(key) {
        return dict[key].
    } else {
        // print "default: " + key + " " + default.
        return default.
    }
}

function simple_q {
    // returns a non accurate dynamic pressure-like reading
    // that can be used for some contol purposes
    parameter height.
    parameter velocity.

    return 0.00000840159*constant:e^(-height/5000)*velocity^2.
}

function simple_q_root {
    // returns a non accurate dynamic pressure-like reading
    // that can be used for some contol purposes
    parameter height.
    parameter velocity.

    return 0.0028985496*constant:e^(-height/5000/2)*velocity.
}

function simple_E {
    // returns a non accurate dynamic pressure-like reading
    // that can be used for some contol purposes
    parameter height.
    parameter velocity.

    return 0.5*velocity^2 - ship:body:mu/(height + ship:body:radius).
}

// try to get param file
// if local param does not exist, create an empty file
function get_param_file {
    parameter search_path.
    parameter filename.
    if not search_path:endswith("/") {
        set search_path to search_path + "/".
    }
    if exists(search_path+filename+".json") {
        copypath(search_path+filename+".json","param.json").
    } else {
        print "param file not found in " + search_path.
    }
    
    if not exists("param.json") {
        print "local param file not found".
        writeJson(lexicon(),"param.json").
    }
}

// try to find a param file with the same name as the element
function get_element_param_file {
    parameter search_path.
    get_param_file(search_path, core:element:name).
}

// try to find a param file with the same name as boot script
function get_boot_param_file {
    parameter search_path.
    get_param_file(search_path, core:bootfilename:replace("/boot/",""):replace(".ks","")).
}

function get_ancestor_with_module {
    parameter module_str.
    parameter return_one_less is false.
    parameter walk_max is 10.

    local current_part is core:part.
    for i in range(0,walk_max) {

        if current_part:hasparent and 
            current_part:parent:hasmodule(module_str) {
            if return_one_less {
                return current_part.
            } else {
                return current_part:parent.
            }
        } else if current_part:hasparent {
            set current_part to current_part:parent.
        } else {
            return -1.
        }
    }
    return -1. // not found error condition
}

function get_child_with_module {
    parameter module_str.
    parameter return_one_less is false.
    parameter walk_max is 10.
    parameter current_part is core:part.

    if walk_max > 0 {
        for child in current_part:children {
            if child:hasmodule(module_str) {
                return child.
            }
        }
        for child in current_part:children {
            local grandchild is
                get_child_with_module(module_str,return_one_less,walk_max-1,child).
            if not (grandchild = -1) {
                if return_one_less {
                    return child.
                } else {
                    return grandchild.
                }
            }
        }
    }
    return -1. // not found error condition
}

local Vslast is 0.0.
local prev_land is SHIP:STATUS.
function display_land_stats {
    if not (SHIP:STATUS = prev_land) {
        if SHIP:STATUS = "LANDED" {
            local land_stats is "landed" + char(10) +
                "  pitch "+ round_dec(pitch,2) + char(10) +
                "  v/vs  "+ round_dec(ship:airspeed,2) + "/"+round_dec(Vslast,2).
            if defined UTIL_HUD_ENABLED {
                util_hud_push_left("AERO_W_LAND_STATS" , land_stats ).
            }
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event(land_stats).
            }
            print land_stats.
        } else if SHIP:STATUS = "FLYING" {
            if defined UTIL_HUD_ENABLED {
                util_hud_pop_left("AERO_W_LAND_STATS").
            }
        }
        set prev_land to SHIP:STATUS.
    }
    if ship:status = "FLYING" {
        SET Vslast to ship:verticalspeed.
    }
}

// Global plane data
function add_plane_globals {
    when true then {
        set vel to ship:airspeed.
        set DELTA_FACE_UP to R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
        set pitch to (mod(DELTA_FACE_UP:pitch+90,180)-90).
        set roll to (180-DELTA_FACE_UP:roll).
        set yaw to (360-DELTA_FACE_UP:yaw).

        set DELTA_PRO_UP to R(90,0,0)*(-SHIP:UP)*
            (choose SHIP:srfprograde if ship:altitude < 36000 else SHIP:prograde).
        set vel_pitch to (mod(DELTA_PRO_UP:pitch+90,180)-90).
        set vel_bear to (360-DELTA_PRO_UP:yaw).

        set ship_vel_dir to LOOKDIRUP(ship:velocity:surface, ship:facing:topvector).
        set alpha_beta_dir to (-ship:facing*ship_vel_dir).
        set alpha to wrap_angle(alpha_beta_dir:pitch).
        set beta to wrap_angle(-alpha_beta_dir:yaw).
        
        return true.
    }
    wait 0.
}

// Global plane data
function get_plane_globals {
    set vel to ship:airspeed.
    set DELTA_FACE_UP to R(90,0,0)*(-SHIP:UP)*(SHIP:FACING).
    set pitch to (mod(DELTA_FACE_UP:pitch+90,180)-90).
    set roll to (180-DELTA_FACE_UP:roll).
    set yaw to (360-DELTA_FACE_UP:yaw).

    set DELTA_PRO_UP to R(90,0,0)*(-SHIP:UP)*
        (choose SHIP:srfprograde if ship:altitude < 36000 else SHIP:prograde).
    set vel_pitch to (mod(DELTA_PRO_UP:pitch+90,180)-90).
    set vel_bear to (360-DELTA_PRO_UP:yaw).

    set ship_vel_dir to LOOKDIRUP(ship:velocity:surface, ship:facing:topvector).
    set alpha_beta_dir to (-ship:facing*ship_vel_dir).
    set alpha to wrap_angle(alpha_beta_dir:pitch).
    set beta to wrap_angle(-alpha_beta_dir:yaw).

}
