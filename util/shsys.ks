
GLOBAL UTIL_SHSYS_ENABLED IS true.

local cargo_bay_opened_count is 0.
local other_ships is UNIQUESET().

IF NOT (DEFINED UTIL_SHSYS_ARM_RLAUNCH_STATUS) { global UTIL_SHSYS_ARM_RLAUNCH_STATUS is false.}

IF NOT (DEFINED MAIN_ENGINE_NAME) { global MAIN_ENGINE_NAME is "".}
IF NOT (DEFINED MAIN_ANTENNAS_NAME) { global MAIN_ANTENNAS_NAME is "".}
IF NOT (DEFINED AUX_ANTENNAS_NAME) { global AUX_ANTENNAS_NAME is "".}



local main_engines is get_parts_tagged(MAIN_ENGINE_NAME).
local main_antennas is get_parts_tagged(MAIN_ANTENNAS_NAME).
local aux_antennas is get_parts_tagged(AUX_ANTENNAS_NAME).


local prev_status is "NA".
local arm_panels_and_antennas is false.
local arm_for_reentry is false.
local arm_parachutes is false.


// sets systems according to where spacecraft is
local function iterate_spacecraft_system_state {
    if UTIL_SHSYS_ARM_RLAUNCH_STATUS {
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
        if arm_panels_and_antennas and ship:altitude > UTIL_SHSYS_ATMOS_ESCAPE_ALT 
            and ship:verticalspeed >= 0 {
            set arm_panels_and_antennas to false.
            print "SHSYS: PANELS".
            print "SHSYS: antennas".

            until (STAGE:NUMBER <= UTIL_SHSYS_ATMOS_ESCAPE_STAGE) {
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

        if arm_for_reentry and ship:altitude < UTIL_SHSYS_REENTRY_ALT
            and ship:verticalspeed < 0 {
            set arm_for_reentry to false.
            set arm_parachutes to true.
            print "SHSYS: reentry".

            until (STAGE:NUMBER <= UTIL_SHSYS_REENTRY_STAGE) {
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
            (ship:altitude < (UTIL_SHSYS_PARACHUTE_ALT- ship:geoposition:terrainheight)){
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
    parameter received.

    set opcode to received:content[0].
    if not opcode:startswith("SYS") {
        return.
    } else if received:content:length > 1 {
        set data to received:content[1].
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
        util_shbus_rx_send_back_ack("could not decode shsys rx msg").
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
