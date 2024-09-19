
GLOBAL AP_MISSILE_ENABLED IS TRUE.

local PARAM is get_param(readJson("param.json"), "AP_MISSILE", lexicon()).

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
        local acc is -9.81*ship:up:vector.

        local isp is ap_orb_get_me_params()[1]:z.

        local dv_c is isp*9.81*ln(max(1,ship:mass/ship:drymass)). // available dv

        set intercept_t to intercept_t - (time:seconds - t_last).
        set intercept_t to newton_one_step_intercept(intercept_t, pos, vel, acc, dv_c).
        set t_last to time:seconds.

        set dv_r to -(vel + pos/intercept_t + 0.5*acc*intercept_t).

        set AP_NAV_VEL to ap_nav_get_vessel_vel() + dv_r.
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        
        util_hud_push_left( "navtest",
            // "int  " + round_dec(intercept_t,3) + char(10) +
            (choose "*" if (dv_c+0.2 > dv_r:mag and intercept_t > 0) else "") +
            "dv " + round_dec(dv_r:mag,1) + char(10)
            // "m/mf " + round_dec(ship:mass,4)+"/"+round_dec(ship:drymass,4) + char(10) +
            ).

        set missile_debug_vec1 to VECDRAW(V(0,0,0), min(10,dv_r:mag)*(dv_r:normalized), RGB(0,1,0),
            "", 1.0, true, 0.25, true ).
        return true.
    } else {
        set AP_NAV_VEL to ap_nav_get_vessel_vel().
        set AP_NAV_ACC to V(0,0,0).
        set AP_NAV_ATT to ship:facing.
        return false.
    }
}
