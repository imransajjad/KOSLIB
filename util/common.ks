// util_common.ks

// a set of common utilities 

set pi to 3.14159265359.
set DEG2RAD to pi/180.
set RAD2DEG to 180/pi.
set g0 to 9.806.

function sat {
    parameter X.
    parameter Lim is 1.0.
    IF X > Lim { return Lim.}
    IF X < -Lim { return -Lim.}
    return X.
}

function deadzone {
    parameter X.
    parameter BAND.
    If X > BAND { return X-BAND.}
    If X < -BAND { return X+BAND.}
    return 0.
}

function convex {
    parameter X.
    parameter Y.
    parameter e.
    return (1-e)*X + e*Y.
}

function round_dec {
    parameter NUM.
    parameter FRAD_DIG.
    return ROUND(NUM*(10^FRAD_DIG))/(10^FRAD_DIG).
}

function list_print {
    parameter arg_in.
    LOCAL TOTAL_STRING is "".
    for e in arg_in{
        SET TOTAL_STRING TO TOTAL_STRING+e+ " ".
    }
    PRINT TOTAL_STRING.
}

function float_list_print {
    parameter arg_in.
    parameter flen.
    LOCAL TOTAL_STRING is "".
    for e in arg_in{
        SET TOTAL_STRING TO TOTAL_STRING+round_dec(e,flen)+ " ".
    }
    PRINT TOTAL_STRING.
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
    local total is wrap_angle_until(90-dir_temp:pitch).
    local roll is dir_temp:roll.
    local eject is wrap_angle_until(dir_temp:yaw).
    return list( eject, total, roll ).
}

function dir_haversine {
    parameter have_list. // eject, total, roll
    return R(-90,0,0)*R(90-have_list[1],have_list[0],have_list[2]).
    // return R(-90,0,0)*R(0,have_list[0],0)*R(90-have_list[1],0,0)*R(0,0,have_list[2]).
    // return R(0,0,have_list[0])*R(have_list[1],0,0).
}

function pitch_yaw_from_dir {
    parameter dir.
    local guide_dir_py to R(90,0,0)*(-SHIP:UP)*dir.
    return list( (mod(guide_dir_py:pitch+90,180)-90) ,
                 (360-guide_dir_py:yaw) ).
}

function remainder {
    parameter x.
    parameter divisor.
    return x - floor(x/divisor).
}

function outerweight {
    parameter x.
    parameter xmin is 0.5.
    parameter xsat is 1.5.

    return sat(deadzone(abs(x),xmin)/(xsat-xmin),1.0).
}

function is_active_vessel {
    return (KUniverse:ActiveVessel = SHIP).
}

function get_engines {
    parameter tag.
    local main_engine_list is LIST().
    if not (tag = "") {
        for e in SHIP:PARTSDUBBED(tag){
            main_engine_list:add(e).
        }
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
        IF ECHO {print RECEIVED:CONTENT.}
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
        return default.
    }
}

function get_frame_accel_orbit {
    // returns a force that if subtracted from the ship
    // will result in a constant height in SOI
    return ship:up:vector*(-1.0*g0 +
        (VECTOREXCLUDE(ship:up:vector,ship:velocity:orbit):mag^2
        /(ship:altitude+ship:body:radius))).
}

function get_frame_accel {
    // if the negative of this value is applied to ship
    // it will always move in a straight line in sidereal frame

    return ship:up:vector*(-1.0*g0).
}

function simple_q {
    // returns a non accurate dynamic pressure-like reading
    // that can be used for some contol purposes
    parameter height.
    parameter velocity.

    return 0.00000840159*constant:e^(-height/5000)*velocity^2.
}

// requires a global called SHIP_TAG_IN_PARAMS
function spin_if_not_us {
    until (SHIP_TAG_IN_PARAMS = string_acro(ship:name) ) {
        wait 1.0.
    }
}

// requires a global called SHIP_TAG_IN_PARAMS
function spin_if_not_core {
    until (SHIP_TAG_IN_PARAMS = core:tag ) {
        wait 0.01.
    }
}

// try to get param file in decreasing order of specificity
function get_param_file {
    if exists("0:/param/"+string_acro(ship:name)+core:tag+".json") {
        copypath("0:/param/"+string_acro(ship:name)+core:tag+".json","param.json").
    } else if exists("0:/param/"+core:tag+".json") {
        copypath("0:/param/"+core:tag+".json","param.json").
    } else if exists("0:/param/"+string_acro(ship:name)+".json") {
        copypath("0:/param/"+string_acro(ship:name)+".json","param.json").
    }
}
