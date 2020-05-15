
GLOBAL UTIL_SHSYS_ENABLED IS true.

local cargo_bay_opened_count is 0.
local other_ships is UNIQUESET().

local PARAM is readJson("param.json")["UTIL_SHSYS"].


local MAIN_ANTENNAS_NAME is (choose PARAM["MAIN_ANTENNAS_NAME"]
        if PARAM:haskey("MAIN_ANTENNAS_NAME") else "").
local AUX_ANTENNAS_NAME is (choose PARAM["AUX_ANTENNAS_NAME"]
        if PARAM:haskey("AUX_ANTENNAS_NAME") else "").

local ARM_RLAUNCH_STATUS is (choose PARAM["ARM_RLAUNCH_STATUS"]
        if PARAM:haskey("ARM_RLAUNCH_STATUS") else false).

local ATMOS_ESCAPE_STAGE is (choose PARAM["ATMOS_ESCAPE_STAGE"]
        if PARAM:haskey("ATMOS_ESCAPE_STAGE") else false).
local ATMOS_ESCAPE_ALT is (choose PARAM["ATMOS_ESCAPE_ALT"]
        if PARAM:haskey("ATMOS_ESCAPE_ALT") else false).

local REENTRY_STAGE is (choose PARAM["REENTRY_STAGE"]
        if PARAM:haskey("REENTRY_STAGE") else false).
local REENTRY_ALT is (choose PARAM["REENTRY_ALT"]
        if PARAM:haskey("REENTRY_ALT") else false).
local PARACHUTE_ALT is (choose PARAM["PARACHUTE_ALT"]
        if PARAM:haskey("PARACHUTE_ALT") else false).

local PARAM is readJson("1:/param.json").
local MAIN_ENGINE_NAME is (choose PARAM["AP_ENGINES"]["MAIN_ENGINE_NAME"]
        if PARAM:haskey("AP_ENGINES") and
        PARAM["AP_ENGINES"]:haskey("MAIN_ENGINE_NAME") else "").


local main_engines is get_parts_tagged(MAIN_ENGINE_NAME).
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
    parameter opcode.
    parameter data.

    if not opcode:startswith("SYS") {
        return.
    }

    IF opcode:startswith("SYS_CB_OPEN") {
        set cargo_bay_opened_count to cargo_bay_opened_count + 1.
        set bays to true.
    } ELSE IF opcode = "SYS_CB_CLOSE" {
        set bays to false.
    } ELSE IF opcode = "SYS_PL_AWAY" {
        wait 0.1.
        get_another_ship(ship:name+" Probe").
    } else {
        util_shbus_tx_msg("ACK", list("could not decode shsys rx msg"), list(sender)).
        print "could not decode shsys rx msg".
        return false.
    }
    return true.
}

// main function for ship systems
function util_shsys_check {

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
