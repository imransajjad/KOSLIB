// util_common.ks

// a set of common utilities 

set pi to 3.14159265359.
set DEG2RAD to pi/180.
set RAD2DEG to 180/pi.
set g0 to 9.806.

FUNCTION sat {
    PARAMETER X.
    PARAMETER Lim is 1.0.
    IF X > Lim { RETURN Lim.}
    IF X < -Lim { RETURN -Lim.}
    RETURN X.
}

FUNCTION deadzone {
    PARAMETER X.
    PARAMETER BAND.
    If X > BAND { RETURN X-BAND.}
    If X < -BAND { RETURN X+BAND.}
    RETURN 0.
}

FUNCTION angle_vectors {
    PARAMETER v1.
    PARAMETER v2.
    RETURN ARCCOS(vdot(v2,v1)/sqrt(vdot(v1,v1)*vdot(v2,v2))).
}

FUNCTION round_dec {
    PARAMETER NUM.
    PARAMETER FRAD_DIG.
    RETURN ROUND(NUM*(10^FRAD_DIG))/(10^FRAD_DIG).
}

FUNCTION list_print {
    PARAMETER arg_in.
    LOCAL TOTAL_STRING is "".
    for e in arg_in{
        SET TOTAL_STRING TO TOTAL_STRING+e+ " ".
    }
    PRINT TOTAL_STRING.
}

FUNCTION float_list_print {
    PARAMETER arg_in.
    PARAMETER flen.
    LOCAL TOTAL_STRING is "".
    for e in arg_in{
        SET TOTAL_STRING TO TOTAL_STRING+round_dec(e,flen)+ " ".
    }
    PRINT TOTAL_STRING.
}

FUNCTION wrap_angle_until {
    PARAMETER theta.
    UNTIL (theta < 180){
        SET theta TO theta-360.
    }
    UNTIL (theta >= -180){
        SET theta TO theta+360.
    }
    return theta.
}

FUNCTION wrap_angle {
    PARAMETER theta.
    PARAMETER max_angle is 360.
    return remainder(theta+max_angle/2,max_angle)-max_angle/2.
}

FUNCTION unit_vector {
    parameter vector_in.
    return (1.0/vector_in:mag)*vector_in.
}

FUNCTION listsum {
    PARAMETER L.
    LOCAL TOTAL IS 0.
    for e in L{
        SET TOTAL TO TOTAL+e.
    }
    RETURN TOTAL.
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
    print "get_parts_tagged " + tag.
    print tagged_list.
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
    PARAMETER ECHO is true.
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
