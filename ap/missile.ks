
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
// local intercept_possible is false.
local t_last is time:seconds.
local t_print is time:seconds.
function ap_missile_guide {

    local launched is true.
    local target_ship is -1.
    if defined UTIL_SHSYS_ENABLED {
        set target_ship to util_shsys_get_target().
        set launched to util_shsys_check().
    } else if HASTARGET {
        set target_ship to TARGET.
    }

    if not (target_ship = -1) {
        local pos is ship:position - target_ship:position.
        local vel is ap_nav_get_vessel_vel() - ap_nav_get_vessel_vel(target_ship).
        local acc is GRAV_ACC.

        local available_dv is 0.
        if defined UTIL_SHSYS_ENABLED and not launched {
            set available_dv to 600.
        } else if defined AP_ORB_ENABLED {
            set available_dv to available_dv + ap_me_get_dv():z.
        }

        set intercept_t to intercept_t - (time:seconds - t_last).
        set intercept_t to newton_one_step_intercept(intercept_t, pos, vel, acc, available_dv).
        set t_last to time:seconds.

        local dv_r is -(vel + pos/intercept_t + 0.5*acc*intercept_t).
        local dv_def is dv_r:mag-available_dv.

        if intercept_t > 0 and intercept_t < 12.5 {
            set dv_r to convex(20.0,1.0,intercept_t/12.5)*dv_r.
        }

        if time:seconds - t_print > 0.2 {
            set t_print to time:seconds.
            local print_str is  "" + core:tag + char(10) +
                    "dp " + round_dec(dv_r:mag*intercept_t,1) + " m" + char(10) +
                    "<dv " + round_dec(dv_def,1) + " m/s" + char(10) +
                    "t " + round_dec(intercept_t,1) + " s".
            ap_missile_guide_hud_print(print_str).
        }
            

        set AP_NAV_VEL to ap_nav_get_vessel_vel() + dv_r.
        set AP_NAV_ACC to GRAV_ACC.
        set AP_NAV_ATT to ship:facing.
        return true.
    } else {
        // set intercept_possible to false.
        set intercept_t to 10.
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        
        ap_missile_guide_cleanup().
        return false.
    }
}

local hud_printed is true.
function ap_missile_guide_hud_print {
    parameter print_str.

    local local_print is true.
    if defined UTIL_SHSYS_ENABLED and not util_shsys_check() {
        set local_print to false.
    }
    if local_print and defined UTIL_HUD_ENABLED {
        util_hud_push_left(core:tag+"missile_int", print_str).
    } else if not local_print and defined UTIL_SHBUS_ENABLED {
        util_shbus_tx_msg("HUD_PUSHL", list(core:tag+"missile_int", print_str)).
    } else {
        print print_str.
    }
    set hud_printed to true.
}

function ap_missile_guide_cleanup {
     if hud_printed {
        if defined UTIL_HUD_ENABLED {
            util_hud_pop_left(core:tag+"missile_int").
        }
        if defined UTIL_SHBUS_ENABLED {
            util_shbus_tx_msg("HUD_POPL", list(core:tag+"missile_int")).
        }
        set hud_printed to false.
    }
}
