
global AP_ME_ENABLED is true.

local METvec is V(0,0,1). // is a vector
local MEIsp is V(0,0,0). // is also a vector is exhaust velocity in multiple directions
local MEMom is V(0,0,0). // is also a vector of moment in ship facing frame
local last_available_thrust is -1.
local function ap_me_params {
    // Main Engine Stuff
    // return the ME thrust vector and the Isp vector
    set last_available_thrust to ship:availablethrust + stage:number.
    list engines in engine_list.
    set METvec to V(0,0,0).
    set MEIsp to V(0,0,0).
    set MEMom to V(0,0,0).

    for e in engine_list {
        until e:availablethrust = 0 or (e:availablethrust > 0 and e:isp > 0) {
            // sometimes engine is activated but isp is still zero. wait till valid
            wait 0.
        }

        if e:ignition and e:availablethrust > 0 and e:isp > 0 {
            local evec is e:availablethrust*((-ship:facing)*e:facing:forevector).
            set METvec to METvec + evec.
            set MEIsp to MEIsp + evec/e:isp.
            set MEMom to MEMom + vcrs((-ship:facing)*e:position,evec).
        }
    }
    if MEIsp:x > 0.0001 { set MEIsp:x to METvec:x/MEIsp:x. }
    if MEIsp:y > 0.0001 { set MEIsp:y to METvec:y/MEIsp:y. }
    if MEIsp:z > 0.0001 { set MEIsp:z to METvec:z/MEIsp:z. }

    print "ME data" +
        char(10) +"last " + round_fig(last_available_thrust,3) + 
        char(10) +"F " + round_vec(METvec,3) +
        char(10) +"Isp " + round_vec(MEIsp,3) +
        char(10) +"Mom " + round_vec(MEMom,3).
}

function ap_me_get_thrust
{
    if ( abs(ship:availablethrust + stage:number - last_available_thrust) > 0.25) {
        ap_me_params().
    }
    return METvec.
}

function ap_me_get_isp
{
    if ( abs(ship:availablethrust + stage:number - last_available_thrust) > 0.25) {
        ap_me_params().
    }
    return MEIsp.
}

function ap_me_get_mom
{
    if ( abs(ship:availablethrust + stage:number - last_available_thrust) > 0.25) {
        ap_me_params().
    }
    return MEMom.
}

function ap_me_get_dv
{
    if ( abs(ship:availablethrust + stage:number - last_available_thrust) > 0.25) {
        ap_me_params().
    }
    local m_engine_prop is 0.
    for r in ship:resources {
        if r:name = "LiquidFuel" or r:name = "Oxidizer" or r:name = "SolidFuel"  {
            set m_engine_prop to m_engine_prop + r:amount*r:density.
        }
    }
    return constant:g0*MEIsp*ln(max(1,ship:mass/(ship:mass - m_engine_prop))).
}

function ap_me_throttle {
    parameter input_throttle is SHIP:CONTROL:PILOTMAINTHROTTLE.
    if SAS {
        return.
    }
    set SHIP:CONTROL:MAINTHROTTLE to input_throttle.
}