
local PARAM is get_param(readJson("param.json"),"UTIL_PHYS", lexicon()).

local C_SCHED_TYPE is get_param(PARAM, "C_SCHED_TYPE", "FS3T").

global lock GRAV_ACC to -(ship:body:mu/((ship:altitude + ship:body:radius)^2))*ship:up:forevector.

// initialize/assign schedule functions
if C_SCHED_TYPE = "FS3T" {
    set cl_sched_assigned to cl_sched_fs3t@.
    set cd_sched_assigned to cd_sched_fs3t@.
} else if C_SCHED_TYPE = "ASM" {
    set cl_sched_assigned to cl_sched_fs3t@.
    set cd_sched_assigned to cd_sched_fs3t@.
}

local function cl_sched_fs3t {
    parameter v.

    if ( v < 100) {
        return -(5/100)*v + 8.5.
    } else if (v < 300) {
        return -(2.5/200)*v + 4.75.
    } else if (v < 2100) {
        return -(0.2/700)*v + 1.09.
    } else {
        return 0.49.
    }
}

local function cd_sched_fs3t {
    parameter v.

    if (v < 50) {
        return 1.0.
    } else if ( v < 100) {
        return -(0.5/50)*v + 1.5.
    } else if (v < 300) {
        return 0.5.
    } else if (v < 400) {
        return (1.0/100)*v - 2.5.
    } else if (v < 500) {
        return -(0.3/100)*v + 2.7.
    } else {
        return 1.2.
    }
}


function cl_sched {
    parameter v.
    return cl_sched_assigned:call(v).
}

function cd_sched {
    parameter v.
    return cd_sched_assigned:call(v).
}


local Tlast is 0.
local Vlast is V(0,0,0).
local acc_now is V(0,0,0).
function get_applied_acc {
    if time:seconds-Tlast > 0.02 {
        set acc_now to 0.5*(ship:velocity:surface-Vlast)/(time:seconds-Tlast) + 0.5*acc_now.
        set Vlast to ship:velocity:surface.
        set Tlast to time:seconds.
    }
    return acc_now-GRAV_ACC.
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
