
GLOBAL AP_NAV_ORB_ENABLED IS TRUE.
local PARAM is get_param(readJson("param.json"), "AP_NAV_ORB", lexicon()).

local thrust_vector is V(0,0,1).
local thrust_string is "x".
// is a vector in the current ship:facing frame
// note that controlpart alters ship:facing frame

local function orb_stick {
    
    if defined AP_MODE_ENABLED and AP_MODE_NAV {
        local delta is ship:control:pilottranslation.
        if (delta):mag > 0.5 and (delta-thrust_vector):mag > 0.5 {
            set thrust_vector to delta:normalized.
            set thrust_string to "" + 
                (choose char(8592) if delta:x < -0.5 else "") +
                (choose char(8594) if delta:x > 0.5 else "") +
                (choose char(8595) if delta:y < -0.5 else "") +
                (choose char(8593) if delta:y > 0.5 else "") +
                (choose "o" if delta:z < -0.5 else "") +
                (choose "x" if delta:z > 0.5 else "").
        }
    }
}

local mannode_maneuver_time is 0.

// function that sets nav parameters to execute present/future nodes
function ap_nav_orb_mannode {

    orb_stick().

    local steer_time is 10. // get from orb if possible
    local buffer_time is 1.
    local no_steer_dv is 0.1.
    if ISACTIVEVESSEL and HASNODE {
        local mannode_delta_v is NEXTNODE:deltav:mag.
        if defined AP_ORB_ENABLED {
            set mannode_maneuver_time to ap_orb_maneuver_time(NEXTNODE:deltav,thrust_vector).
            set steer_time to ap_orb_steer_time(NEXTNODE:deltav).
            set no_steer_dv to ap_orb_rcs_dv().
        }

        set AP_NAV_ACC to V(0,0,0).
        if NEXTNODE:eta < mannode_maneuver_time/2 + buffer_time {
            if mannode_delta_v < 0.01 {
                print "remaining node " + char(916) + "v " + round_fig(mannode_delta_v,3) + " m/s".
                set mannode_maneuver_time to 0.
                set AP_NAV_VEL to ship:velocity:orbit.
                set AP_NAV_ATT to ship:facing.
                REMOVE NEXTNODE.
            } else {
                // do burn
                set AP_NAV_VEL to ship:velocity:orbit + NEXTNODE:deltav.
                if NEXTNODE:deltav:mag > no_steer_dv {
                    local omega is -1*vcrs(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
                    local omega_mag is vectorAngle(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
                    set AP_NAV_ATT to angleaxis( omega_mag, omega:normalized )*ship:facing.
                }
            }
        } else if NEXTNODE:eta < mannode_maneuver_time/2 + buffer_time + steer_time {
            // steer to burn direction
            if not (kuniverse:timewarp:rate = 0) {
                set kuniverse:timewarp:rate to 0.
            }
            set AP_NAV_VEL to ship:velocity:orbit.
            local omega is -1*vcrs(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
            local omega_mag is vectorAngle(NEXTNODE:deltav:normalized, ship:facing*thrust_vector).
            set AP_NAV_ATT to angleaxis( omega_mag, omega:normalized )*ship:facing.
        } else {
            // do nothing
            set AP_NAV_VEL to ship:velocity:orbit.
            set AP_NAV_ATT to ship:facing.
        }
        
        return true.

    } else if ISACTIVEVESSEL {
        set AP_NAV_VEL to ship:velocity:orbit.
        set AP_NAV_ATT to ship:facing.
    } else {
        set mannode_maneuver_time to 0.
        return false.
    }
}

function ap_nav_orb_status_string {
    local dstr is "".
    local mode_str is "".
    local vel_mag is ap_nav_get_hud_vel():mag.

    if mannode_maneuver_time <> 0 {
        set dstr to char(10) + char(916) + "v " +round_fig((AP_NAV_VEL-ship:velocity:orbit):mag,2)
            + "|" + thrust_string + round_fig(mannode_maneuver_time,2) + "s " +
            + (choose char(10) + "T " + round_fig(-NEXTNODE:eta,2) + "s" if HASNODE else "").
    }
    set DISPLAY_ORB to false.
    set mode_str to mode_str + "o".
    set dstr to dstr + (choose "" if mode_str = "" else char(10)+mode_str).

    return dstr.
}
