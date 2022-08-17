
local PARAM is get_param(readJson("param.json"),"UTIL_PHYS", lexicon()).

local C_SCHED_TYPE is get_param(PARAM, "C_SCHED_TYPE", "FS3T").

local A_wing is get_param(PARAM, "WING_AREA", 20).
local A_fues is get_param(PARAM, "FUES_AREA", 2).
local A_ffactor is get_param(PARAM, "FORGET_FACTOR_AREA", 0.9).

// global lock GRAV_ACC to -(ship:body:mu/((ship:altitude + ship:body:radius)^2))*ship:up:forevector.
global lock GRAV_ACC to ship:body:mu/(ship:body:position:mag^2)*(ship:body:position:normalized).

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
local acclast is V(0,0,0).
local jerk_now is V(0,0,0).
function get_acc {
    if time:seconds-Tlast > 0.0 {
        set acc_now to 0.5*(ship:velocity:orbit-Vlast)/(time:seconds-Tlast) + 0.5*acc_now.
        set jerk_now to 0.5*(acc_now-acclast)/(time:seconds-Tlast) + 0.5*jerk_now.
        set Vlast to ship:velocity:orbit.
        set acclast to acc_now.
        set Tlast to time:seconds.
    }
    return acc_now.
}

function get_jerk {
    get_acc().
    return jerk_now.
}

function get_applied_acc {
    return get_acc() - GRAV_ACC.
}

function get_aero_acc {
    if defined AP_AERO_ENGINES_ENABLED {
        return get_acc() - GRAV_ACC - ap_aero_engines_get_current_thrust()/ship:mass.
    } else {
        return get_acc() - GRAV_ACC.
    }
}

function get_frame_accel_orbit {
    // returns a force that if subtracted from the ship
    // will result in a constant height in SOI
    return GRAV_ACC + ship:up:vector*
    ((VECTOREXCLUDE(ship:up:vector,ship:velocity:orbit):mag^2
        /(ship:altitude+ship:body:radius))).
}

function get_frame_accel {
    // if the negative of this value is applied to ship
    // it will always move in a straight line in sidereal frame

    return ship:up:vector*(-1.0*g0).
}

function get_max_applied_acc {
    return abs_max(get_applied_acc()*ship:facing:topvector, get_applied_acc()*ship:facing:forevector).
}



// RLS matrix elements
local A_11 is 1.
local A_21_12 is 0.
local A_22 is 1.
local function aero_rls_update {

    // Do a Recursive Least Square filter to estimate two values
    // Fueselage Area and Wing Area that minimize the cumulative vector error
    // e = ( A_fues*e_fues + A_wing*e_wing ) - aero_forces
    // e_fues is a a vector pointing in the direction of fueselage aero force
    // e_wing is a a vector pointing in the direction of wing aero force
    local e_fues is ship:q/ship:mass*V(0, -cl_sched(ship:airspeed)*sin(alpha)*cos(alpha), -cd_sched(ship:airspeed)*cos(alpha)^2).
    local e_wing is ship:q/ship:mass*V(0, cl_sched(ship:airspeed)*sin(alpha)*cos(alpha), -cd_sched(ship:airspeed)*sin(alpha)^2).

    local e_11 is e_fues*e_fues.
    local e_21_12 is e_fues*e_wing.
    local e_22 is e_wing*e_wing.

    local vel_acc is (-ship_vel_dir)*get_aero_acc().
    local e_fues_y is e_fues*vel_acc.
    local e_wing_y is e_wing*vel_acc.

    set A_11 to A_ffactor*A_11 + e_11.
    set A_21_12 to A_ffactor*A_21_12 + e_21_12.
    set A_22 to A_ffactor*A_22 + e_22.

    local disc is (A_11*A_22 - A_21_12^2).
    local diff1 is e_fues_y - e_11*A_fues - e_21_12*A_wing.
    local diff2 is e_wing_y - e_21_12*A_fues - e_22*A_wing.

    set A_fues to A_fues + (A_22*diff1 - A_21_12*diff2)/disc.
    set A_wing to A_wing + (-A_21_12*diff1 + A_11*diff2)/disc.

    if false {
        local error is (-ship_vel_dir)*get_aero_acc() - ( A_fues*e_fues + A_wing*e_wing).
        util_hud_push_left("get_pre_aero_acc", "eA " + round_dec(error:x,2) + "," + round_dec(error:y,2) + "," + round_dec(error:z,2) +
            char(10) + "A f/w " + round_dec(A_fues,0) + "/" + round_dec(A_wing,0)).
        set phys_debug_vec0 to VECDRAW((ship_vel_dir*( A_fues*e_fues + A_wing*e_wing)), (ship_vel_dir*error), RGB(1,0,0),
                    "", 1.0, true, 0.125, true ).
        set phys_debug_vec1 to VECDRAW(V(0,0,0), (ship_vel_dir*( A_fues*e_fues + A_wing*e_wing)), RGB(0,1,1),
                    "", 1.0, true, 0.125, true ).
        set phys_debug_vec2 to VECDRAW(V(0,0,0), (ship_vel_dir*(A_fues*e_fues)), RGB(0,0.5,1),
                    "", 1.0, true, 0.125, true ).
        set phys_debug_vec3 to VECDRAW( (ship_vel_dir*(A_fues*e_fues)), (ship_vel_dir*(A_wing*e_wing)), RGB(0.5,1.0,0),
                    "", 1.0, true, 0.125, true ).
    }
}

function get_wing_area {
    return A_wing.
}

function get_fues_area {
    return A_fues.
}

function get_pre_aero_acc {
    parameter v is ship:airspeed.
    parameter a is alpha.
    parameter q is ship:q.
    parameter m is ship:mass.

    local e_fues is q/m*V(0, -cl_sched(v)*sin(a)*cos(a), -cd_sched(v)*cos(a)^2).
    local e_wing is q/m*V(0, cl_sched(v)*sin(a)*cos(a), -cd_sched(v)*sin(a)^2).

    return ship_vel_dir*( A_fues*e_fues + A_wing*e_wing).
}

function get_sus_turn_rate {
    parameter v is ship:airspeed.
    parameter a is alpha.
    parameter q is ship:q.
    parameter m is ship:mass.

    local Tmax is (choose ap_aero_engines_get_max_thrust() if defined AP_AERO_ENGINES_ENABLED else 0 ).
    local qcl is q*cl_sched(v).
    local Eta is (Tmax/(q*cd_sched(v)) - A_wing)/(A_fues-A_wing).
    print Eta.

    if Eta > 0 and Eta < 1 {
        local phys_deg_per_sec is q*cl_sched(v)*(A_wing-A_fues)*sqrt(Eta*(1-Eta))/(m*v)*RAD2DEG.
        util_hud_push_left("get_sus_turn_rate", "phpmax " + round_dec(phys_deg_per_sec,1) ).
        return phys_deg_per_sec.
    } else {
        return 2*g0/v*RAD2DEG.
    }
}

local dry_moi is V(1,1,1). // xx, yy, zz
local dry_moi_cross is V(0,0,0). // xy, yz, xz
local dry_moi is V(1,1,1).
local wet_moi_cross is V(0,0,0).

local function init_phys_params {
    // some MOI calculations
    
    set dry_moi to V(0,0,0).
    set dry_moi_cross to V(0,0,0).
    set wet_moi to V(0,0,0).
    set wet_moi_cross to V(0,0,0).

    for pt in ship:parts {

        local offset is -ship:facing*pt:position.

        set dry_moi to dry_moi +
            V(pt:drymass*(offset:y^2 + offset:z^2),
            pt:drymass*(offset:x^2 + offset:z^2),
            pt:drymass*(offset:x^2 + offset:y^2)).
        
        set dry_moi_cross to dry_moi_cross -
            V(pt:drymass*(offset:y*offset:x),
            pt:drymass*(offset:z*offset:y),
            pt:drymass*(offset:z*offset:x)).

        set wet_moi to wet_moi +
            V(pt:wetmass*(offset:y^2 + offset:z^2),
            pt:wetmass*(offset:x^2 + offset:z^2),
            pt:wetmass*(offset:x^2 + offset:y^2)).
        
        set wet_moi_cross to wet_moi_cross -
            V(pt:wetmass*(offset:y*offset:x),
            pt:wetmass*(offset:z*offset:y),
            pt:wetmass*(offset:z*offset:x)).
    }

    print "dry MOI " + dry_moi.
    print "wet MOI " + wet_moi.
}

function get_moment_of_inertia {
    local e is (ship:mass-ship:drymass)/(ship:wetmass - ship:drymass).
    return convex(dry_moi, wet_moi, e).
}

function get_dry_moment_of_inertia {
    return dry_moi.
}

local last_dry_mass is -2.
function util_phys_update {

    if abs(ship:drymass - last_dry_mass) > 0.025 {
        init_phys_params().
        set last_dry_mass to ship:drymass.
    }

    if ship:q > 0.0003 and not BRAKES and alpha > 0 and alpha < 45 and get_jerk():mag < 1.5 {
        // aero_rls_update().
    }
}
