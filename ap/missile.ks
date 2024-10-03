
GLOBAL AP_MISSILE_ENABLED IS TRUE.

local PARAM is get_param(readJson("param.json"), "AP_MISSILE", lexicon()).

local dry_mass is get_param(PARAM, "DRY_MASS", 0.296).

local last_acc_a is V(0,0,0).
local last_vel_a is V(0,0,0).
local last_time_a is time:seconds-0.02.
local last_ship_a is ship.
local last_acc_b is V(0,0,0).
local last_vel_b is V(0,0,0).
local last_time_b is time:seconds.
local last_ship_b is ship.
local last_ship is ship.

local function ap_nav_get_vessel_acc {
    parameter this_vessel is ship.

    util_hud_push_left( "acc_vessel",
                        "acc " + round_vec(ship_vel_dir*last_acc_a,1) ).

    // if (last_ship_a = this_vessel) {
        set last_acc_a to 0.5*last_acc_a + 0.5*(this_vessel:velocity:orbit - last_vel_a)/(time:seconds - last_time_a).
        set last_vel_a to this_vessel:velocity:orbit.
        set last_time_a to time:seconds.
        set last_ship to this_vessel.
        return last_acc_a.
    // } else if (last_ship_b = this_vessel) {
    //     set last_acc_b to 0.5*last_acc_b + 0.5*(this_vessel:velocity:orbit - last_vel_b)/(time:seconds - last_time_b).
    //     set last_vel_b to this_vessel:velocity:orbit.
    //     set last_time_b to time:seconds.
    //     set last_ship to this_vessel.
    //     return last_acc_b.
    // } else {
    //     if (last_ship = last_ship_a) {
    //         set last_ship_b to this_vessel.
    //     } else {
    //         set last_ship_a to this_vessel.
    //     }
        return V(0,0,0).
    // }

}

local function newton_one_step_intercept {
    parameter t.
    parameter init_pos.
    parameter init_vel.
    parameter init_acc.
    parameter dv_C. // available delta v

    if dv_C > 0.1 {
        // minimize t
        local pos is init_pos + init_vel*t + 0.5*init_acc*t*t.
        local vel is init_vel + init_acc*t.
        local acc is init_acc.

        local f is pos*pos - dv_C*pos:mag*t.
        local df is 2*pos*vel - dv_C*pos:mag - dv_C*t*pos*vel/pos:mag.

        return t -f/df.
    } else {
        // minimize delta v
        local rt is init_pos/t + init_vel + 0.5*init_acc*t.
        local dr is -init_pos/(t^2) + 0.5*init_acc.
        local ddr is 2*init_pos/(t^3).

        local df is dr*rt.
        local ddf is ddr*rt + dr*dr.

        return t - df/ddf.
    }
}

// directly set any nav data here for testing
local min_dist is V(1000000,1000000,1000000).
local intercept_t is 10.
local t_last is time:seconds.
local dv_r is 0.
function ap_missile_guide {

    local target_ship is -1.
    if defined UTIL_SHSYS_ENABLED {
        set target_ship to util_shsys_get_target().
    } else if HASTARGET {
        set target_ship to TARGET.
    }

    if not (target_ship = -1) {
        local pos is ship:position - target_ship:position.
        local vel is ap_nav_get_vessel_vel()-ap_nav_get_vessel_vel(target_ship).
        local acc is -9.81*ship:up:vector - ap_nav_get_vessel_acc(target_ship).

        local isp is ap_orb_get_me_isp():z.

        local dv_c is isp*9.81*ln(max(1,ship:mass/dry_mass)). // available dv

        set intercept_t to intercept_t - (time:seconds - t_last).
        set intercept_t to newton_one_step_intercept(intercept_t, pos, vel, acc, dv_c).
        set t_last to time:seconds.

        set dv_r to -(vel + pos/intercept_t + 0.5*acc*intercept_t).

        set AP_NAV_VEL to ap_nav_get_vessel_vel() + dv_r.
        set AP_NAV_ACC to get_frame_accel_orbit().
        set AP_NAV_ATT to ship:facing.

        if (min_dist:mag > target_ship:position:mag) {
            set min_dist to target_ship:position.
        }

        if target_ship:status = "LANDED" {
            if pos:mag < 5000 and not target_ship:loaded {
                set target_ship:loaddistance:landed:load to 5000.
            }
            if pos:mag < 4000 and not target_ship:unpacked {
                set target_ship:loaddistance:landed:unpack to 4000.
            }
        } else if target_ship:status = "SPLASHED" {
            if pos:mag < 5000 and not target_ship:loaded {
                set target_ship:loaddistance:splashed:load to 5000.
            }
            if pos:mag < 4000 and not target_ship:unpacked {
                set target_ship:loaddistance:splashed:unpack to 4000.
            }
        }
        
        util_hud_push_left( "navtest",
            // "int  " + round_dec(intercept_t,3) + char(10) +
            (choose "*" if (dv_c+0.2 > dv_r:mag and intercept_t > 0) else "")
            + "dv/t " + round(dv_r:mag) + "/" + round(intercept_t) + char(10)
            + "min " + round_dec( vectorexclude(vel,min_dist):mag,2)
            // "dva " + round_dec(dv_c,1) + char(10)
            // "m/mf " + round_dec(ship:mass,4)+"/"+round_dec(ship:drymass,4) + char(10) +
            ).

        // set missile_debug_vec1 to VECDRAW(V(0,0,0), min(10,dv_r:mag)*(dv_r:normalized), RGB(0,1,0),
        //     "", 1.0, true, 0.25, true ).
        return true.
    } else {
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        set min_dist to V(1000000,1000000,1000000).
        return false.
    }
}
