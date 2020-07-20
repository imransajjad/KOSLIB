
global AP_NAV_ORB_ENABLED is true.

local in_mannode is false.

local nav_orb_on is false.

// function that is used when no wp is found,
// should just set nav parameters to execute present/future nodes
function ap_nav_orb_stick {
    set AP_NAV_VEL to ship:velocity:orbit.
    set AP_NAV_ACC to V(0,0,0).
    set AP_NAV_ATT to ship:facing.
    set nav_orb_on to true.// (in_mannode or ship:status = "FLYING" or ship:status = "SUB_ORBITAL").
}

function ap_nav_orb_status_string {
    local dstr is "".
    if nav_orb_on {
        set dstr to char(10) + char(916) + "v " +round_fig((AP_NAV_VEL-ship:velocity:orbit):mag,2).
        if ship:orbit:eccentricity < 1.0 {
            if ship:orbit:trueanomaly >= 90 and ship:orbit:trueanomaly < 270{
                local time_hud is eta:apoapsis - (choose 0 if ship:orbit:trueanomaly < 180 else ship:orbit:period).
                set dstr to dstr+char(10)+"Ap "+round(ship:orbit:apoapsis) +
                    char(10)+ " T" + round_fig(-time_hud,1)+"s".
            } else {
                local time_hud is eta:periapsis - (choose 0 if ship:orbit:trueanomaly > 180 else ship:orbit:period).
                set dstr to dstr+char(10)+"Pe "+round(ship:orbit:periapsis) +
                    char(10)+ "T" + round_fig(-time_hud,1)+"s".
            }
        } else {
            if ship:orbit:hasnextpatch and ship:orbit:trueanomaly >= 0 {
                set dstr to dstr+char(10)+"Esc " +
                    char(10)+ " T " + round(ship:orbit:nextpatcheta)+"s".
            } else{
                set dstr to dstr+char(10)+"Pe "+round(ship:orbit:periapsis) +
                    char(10)+ "T " + round(eta:periapsis)+"s".
            }
        }
        set nav_orb_on to false.
    }
    return dstr.
}