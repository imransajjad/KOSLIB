
GLOBAL AP_MISSILE_ENABLED IS TRUE.

local last_acc_a is V(0,0,0).
local last_vel_a is V(0,0,0).
local last_time_a is time:seconds-0.02.

local function ap_missile_get_target_acc {
    parameter this_vessel is ship.

    set last_acc_a to 0.5*last_acc_a + 0.5*(this_vessel:velocity:orbit - last_vel_a)/(time:seconds - last_time_a).
    set last_vel_a to this_vessel:velocity:orbit.
    set last_time_a to time:seconds.
    return last_acc_a.
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

local intercept_t is 10.
local intercept_possible is false.
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
        local acc is GRAV_ACC.

        local available_dv is 0.
        if defined AP_ORB_ENABLED {
            set available_dv to available_dv + ap_orb_get_me_dv():z.
        }

        set intercept_t to intercept_t - (time:seconds - t_last).
        set intercept_t to newton_one_step_intercept(intercept_t, pos, vel, acc, available_dv).
        set t_last to time:seconds.

        set dv_r to -(vel + pos/intercept_t + 0.5*acc*intercept_t).
        if not intercept_possible and abs(dv_r:mag-available_dv) <= 0.5 {
            set intercept_possible to true.
            print "Intercept Possible: " + char(10) +
                    "  " + target_ship:name + char(10) + 
                    "  dv " + round_fig(available_dv,1) + " m/s" + char(10) +
                    "  t " + round_fig(intercept_t,1) + " s". 
        } else if intercept_possible and abs(dv_r:mag-available_dv) > 0.5 {
            set intercept_possible to false.
            print "No Intercept: " + char(10) + target_ship:name.
        }

        set AP_NAV_VEL to ap_nav_get_vessel_vel() + dv_r.
        set AP_NAV_ACC to get_frame_accel_orbit().
        set AP_NAV_ATT to ship:facing.
        return true.
    } else {
        set intercept_possible to false.
        set intercept_t to 10.
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        return false.
    }
}
