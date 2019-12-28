// util_common.ks

// a set of common utilities 

set pi to 3.14159265359.
set DEG2RAD to pi/180.
set RAD2DEG to 180/pi.
set g0 to 9.806.

FUNCTION sat {
    PARAMETER X.
    PARAMETER Lim.
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
    parameter canyon is 5.0. // degrees


    set dlong to -(lng1-lng0).

    set top to cos(lat0)*cos(dlong)*cos(lat1) + sin(lat0)*sin(lat1).
    set fore to sin(lat0)*cos(dlong)*cos(lat1) - cos(lat0)*sin(lat1).
    set left to sin(dlong)*cos(lat1).

    // list[0] is roll
    // list[1] is total angular difference
    return list(arctan2(-left,-fore) ,arccos(top)).

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
