
GLOBAL UTIL_SHSYS_ENABLED IS true.

local cargo_bay_opened_count is 0.
local other_ships is UNIQUESET().

local PARAM is readJson("param.json")["UTIL_SHSYS"].

local sys_unspin is get_param(PARAM, "UNSPIN_ON_START", true).

local GET_PARENT_ENGINE is get_param(PARAM, "GET_PARENT_ENGINE", false).
local SPIN_ON_ENGINE is get_param(PARAM, "SPIN_ON_ENGINE", false).

local MAIN_ANTENNAS_NAME is get_param(PARAM, "MAIN_ANTENNAS_NAME", "").
local AUX_ANTENNAS_NAME is get_param(PARAM, "AUX_ANTENNAS_NAME", "").
local ARM_RLAUNCH_STATUS is get_param(PARAM, "ARM_RLAUNCH_STATUS", "").

local ATMOS_ESCAPE_STAGE is get_param(PARAM, "ATMOS_ESCAPE_STAGE", "").
local ATMOS_ESCAPE_ALT is get_param(PARAM, "ATMOS_ESCAPE_ALT", "").

local REENTRY_STAGE is get_param(PARAM, "REENTRY_STAGE", "").
local REENTRY_ALT is get_param(PARAM, "REENTRY_ALT", "").
local PARACHUTE_ALT is get_param(PARAM, "PARACHUTE_ALT", "").

local PARAM is readJson("1:/param.json").
local MAIN_ENGINE_NAME is "".
if PARAM:haskey("AP_ENGINES") {
    set MAIN_ENGINE_NAME to get_param(PARAM["AP_ENGINES"], "MAIN_ENGINE_NAME", "").
}


local main_engines is get_parts_tagged(MAIN_ENGINE_NAME).
if GET_PARENT_ENGINE {
    // try getting a parent engine
    local stage_engine is get_ancestor_with_module("ModuleEnginesFX").
    if not (stage_engine = -1) { main_engines:add(stage_engine). }
}

local main_antennas is get_parts_tagged(MAIN_ANTENNAS_NAME).
local aux_antennas is get_parts_tagged(AUX_ANTENNAS_NAME).


local prev_status is "NA".
local arm_panels_and_antennas is false.
local arm_for_reentry is false.
local arm_parachutes is false.


// sets systems according to where spacecraft is
local function iterate_spacecraft_system_state {
    if ARM_RLAUNCH_STATUS {
        if not (ship:status = prev_status) {
            set prev_status to ship:status.

            if ship:status = "ORBITING" {
                set arm_panels_and_antennas to true.
                set arm_for_reentry to false.
                // do nothing.
            }
            if ship:status = "PRELAUNCH" {
                // do nothing.
            }
            if (ship:status = "SUB_ORBITAL" or ship:status = "FLYING")
                and ship:verticalspeed >= 0 {
                set arm_panels_and_antennas to true.
            }
            if (ship:status = "SUB_ORBITAL" or ship:status = "FLYING")
                and ship:verticalspeed < 0 {
                set arm_for_reentry to true.
            }
        }

        // open solar panels and antennas if out of atmosphere
        if arm_panels_and_antennas and ship:altitude > ATMOS_ESCAPE_ALT 
            and ship:verticalspeed >= 0 {
            set arm_panels_and_antennas to false.
            print "SHSYS: PANELS".
            print "SHSYS: antennas".

            until (STAGE:NUMBER <= ATMOS_ESCAPE_STAGE) {
                stage.
            }

            set PANELS to true.
            for a in main_antennas {
                a:GETMODULE("ModuleRTAntenna"):doaction("activate", true).
            }
            for a in aux_antennas {
                a:GETMODULE("ModuleRTAntenna"):doaction("activate", true).
            }
        }

        if arm_for_reentry and ship:altitude < REENTRY_ALT
            and ship:verticalspeed < 0 {
            set arm_for_reentry to false.
            set arm_parachutes to true.
            print "SHSYS: reentry".

            until (STAGE:NUMBER <= REENTRY_STAGE) {
                stage.
            }

            set PANELS to false.
            for a in main_antennas {
                a:GETMODULE("ModuleRTAntenna"):doaction("deactivate", true).
            }
            for a in aux_antennas {
                a:GETMODULE("ModuleRTAntenna"):doaction("deactivate", true).
            }
        }
        if arm_parachutes and 
            (ship:altitude < (PARACHUTE_ALT- ship:geoposition:terrainheight)){
            set arm_parachutes to false.
            set CHUTES to true.
            print "SHSYS: CHUTES".
        }
    }
}


local function get_another_ship {
    parameter namestr.
    list targets in target_list.
    local found is false.

    //until found {
        for e in target_list {
            if e:name = namestr and not other_ships:contains(e){
                other_ships:add(e).
                //set found to true.
            }
        }
    //}
}

function util_shsys_decode_rx_msg {
    parameter sender.
    parameter recipient.
    parameter opcode.
    parameter data.

    if not opcode:startswith("SYS") {
        return.
    }

    if opcode:startswith("SYS_UNSPIN") {
        set sys_unspin to true.
    } else if opcode:startswith("SYS_CB_OPEN") {
        set cargo_bay_opened_count to cargo_bay_opened_count + 1.
        set bays to true.
    } else if opcode = "SYS_CB_CLOSE" {
        set bays to false.
    } else if opcode = "SYS_PL_AWAY" {
        wait 0.1.
        get_another_ship(ship:name+" Probe").
    } else if opcode = "SYS_DO_ACTION" {
        util_shsys_do_action(data[0]).
    } else {
        util_shbus_ack("could not decode shsys rx msg", sender).
        print "could not decode shsys rx msg".
        return false.
    }
    return true.
}

// main function for ship systems
// returns true if sys is not blocked.
function util_shsys_check {

    if SPIN_ON_ENGINE and not sys_unspin {
        set sys_unspin to main_engines[0]:ignition.
    }
    // close cargo bay after deploying other ship
    // at a safe distance
    if other_ships:length > 0 {
        local oship_remove is 0.
        for oship in other_ships {
            if oship:distance > 3 {
                set oship_remove to oship.
            }
        }
        if not (oship_remove = 0) {
            set cargo_bay_opened_count to max(0,cargo_bay_opened_count-1).
            other_ships:remove(oship_remove).
            if cargo_bay_opened_count = 0 and other_ships:length = 0 {
                set bays to false.
            }
        }
    }

    iterate_spacecraft_system_state().
    return sys_unspin.
}

function util_shsys_do_action {
    parameter key_in.
    if key_in = "1" {
        toggle AG1.
    } else if key_in = "2" {
        toggle AG2.
    } else if key_in = "3" {
        toggle AG3.
    } else if key_in = "4" {
        toggle AG4.
    } else if key_in = "5" {
        toggle AG5.
    } else if key_in = "6" {
        toggle AG6.
    } else if key_in = "7" {
        toggle AG7.
    } else if key_in = "8" {
        toggle AG8.
    } else if key_in = "9" {
        toggle AG9.
    } else if key_in = "0" {
        toggle AG10.
    } else if key_in = "g" {
        toggle GEAR.
    } else if key_in = "r" {
        toggle RCS.
    } else if key_in = "t" {
        toggle SAS.
    } else if key_in = "u" {
        toggle LIGHTS.
    } else if key_in = "b" {
        toggle BRAKES.
    } else if key_in = "m" {
        toggle MAPVIEW.
    } else if key_in = " " {
        print "stage manually".
    } else {
        print "could not do action " + key_in.
        return false.
    }
    return true.
}

function util_shsys_status_string {
    local stat_list is list().
    for me in main_engines {
        if me:multimode {
            stat_list:add(me:mode[0]).
        }
    }
    if GEAR {
        stat_list:add("G").
    }
    if BRAKES {
        stat_list:add("B").
    }
    if LIGHTS {
        stat_list:add("L").
    }
    return stat_list:join("").
}
