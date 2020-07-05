
GLOBAL UTIL_SHSYS_ENABLED IS true.

local cargo_bay_opened_count is 0.
local other_ships is UNIQUESET().

local PARAM is get_param(readJson("param.json"),"UTIL_SHSYS", lexicon()).

local MAIN_ANTENNAS_NAME is get_param(PARAM, "MAIN_ANTENNAS_NAME", "").
local AUX_ANTENNAS_NAME is get_param(PARAM, "AUX_ANTENNAS_NAME", "").
local ARM_RLAUNCH_STATUS is get_param(PARAM, "ARM_RLAUNCH_STATUS", "").

local ATMOS_ESCAPE_STAGE is get_param(PARAM, "ATMOS_ESCAPE_STAGE", "").
local ATMOS_ESCAPE_ALT is get_param(PARAM, "ATMOS_ESCAPE_ALT", "").

local REENTRY_STAGE is get_param(PARAM, "REENTRY_STAGE", -1).
local REENTRY_ALT is get_param(PARAM, "REENTRY_ALT", -1).
local PARACHUTE_ALT is get_param(PARAM, "PARACHUTE_ALT", 1000).

local Q_SAFE is get_param(PARAM, "Q_SAFE", 0).
local qsafe_last is true.

local MIN_SEPARATION is get_param(PARAM, "MIN_SEPARATION", 3).

local PARAM is readJson("1:/param.json").
local MAIN_ENGINE_NAME is "".
if PARAM:haskey("AP_AERO_ENGINES") {
    set MAIN_ENGINE_NAME to get_param(PARAM["AP_AERO_ENGINES"], "MAIN_ENGINE_NAME", "").
}


local main_engines is get_parts_tagged(MAIN_ENGINE_NAME).
if main_engines:length = 0 {
    // if no tagged engines found try getting a parent engine
    local stage_engine is get_ancestor_with_module("ModuleEnginesFX").
    if (stage_engine = -1) { get_child_with_module("ModuleEnginesFX"). }
    if not (stage_engine = -1) { main_engines:add(stage_engine). }
}

local main_antennas is get_parts_tagged(MAIN_ANTENNAS_NAME).
local aux_antennas is get_parts_tagged(AUX_ANTENNAS_NAME).

local connected_to_decoupler is -1.
local connected_to_decoupler_children_length is -1.

set connected_to_decoupler to get_ancestor_with_module("ModuleDecouple", true).
if (connected_to_decoupler = -1) {
    // in most cases core-> ... -> connected_to_decoupler -> decoupler
    set connected_to_decoupler to get_child_with_module("ModuleDecouple", true).
    if not (connected_to_decoupler = -1) {
        set connected_to_decoupler_children_length to connected_to_decoupler:children:length.
    }
}

local decoupler is -1.
set decoupler to get_ancestor_with_module("ModuleDecouple").
if (decoupler = -1) { get_child_with_module("ModuleDecouple"). }

local reaction_wheels is -1.
set reaction_wheels to get_ancestor_with_module("ModuleReactionWheel").
if (reaction_wheels = -1) { get_child_with_module("ModuleReactionWheel"). }


local prev_status is "NA".
local arm_panels_and_antennas is false.
local arm_for_reentry is false.
local arm_parachutes is false.

local initial_ship is ship.

local SPIN_ON_ENGINE is false.
local SPIN_ON_DECOUPLER is false.
local SPIN_ON_FARING is false.
local SPIN_ON_SEPARATION is false.



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

// main function for ship systems
// returns true if sys is not blocked.
function util_shsys_check {

    // check for fakely staged parts
    if SPIN_ON_ENGINE {
        set SPIN_ON_ENGINE to not main_engines[0]:ignition.
    }
    if SPIN_ON_DECOUPLER {
        if connected_to_decoupler = -1 {
            set SPIN_ON_DECOUPLER to false.
        } else if connected_to_decoupler_children_length >= 0 {
            set SPIN_ON_DECOUPLER to not 
                (connected_to_decoupler:children:length = connected_to_decoupler_children_length) .
        } else {
            set SPIN_ON_DECOUPLER to connected_to_decoupler:hasparent.
        }
        if not SPIN_ON_DECOUPLER { print "unspin on decoupler"+connected_to_decoupler+connected_to_decoupler_children_length.}
    }
    if SPIN_ON_FARING {
        set SPIN_ON_FARING to false. // not implemented yet
    }
    if SPIN_ON_SEPARATION {
        if initial_ship:distance > MIN_SEPARATION {
            set SPIN_ON_SEPARATION to false.
        }
    }
    local do_spin is ( SPIN_ON_ENGINE or SPIN_ON_DECOUPLER or SPIN_ON_FARING or SPIN_ON_SEPARATION).

    // send any safety messages to hud
    if Q_SAFE > 0 {
        if qsafe_last and (ship:q > Q_SAFE){
            print "Q unsafe".
            set qsafe_last to false.
            if defined UTIL_HUD_ENABLED {
                util_hud_push_left("shsys_q", core:tag:split(" ")[0]+"nQS").
            } else if defined UTIL_SHBUS_ENABLED {
                util_shbus_tx_msg("HUD_PUSHL", list(core:tag+"shsys_q", core:tag:split(" ")[0]+"nQS")).
            }
        } else if (not qsafe_last and (ship:q <= Q_SAFE)) or not do_spin {
            print "Q safe".
            set qsafe_last to true.
            if defined UTIL_HUD_ENABLED {
                util_hud_pop_left("shsys_q").
            } else if defined UTIL_SHBUS_ENABLED {
                util_shbus_tx_msg("HUD_POPL", list(core:tag+"shsys_q")).
            }
        }
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
    return not do_spin.
}

function util_shsys_spin {
    until util_shsys_check()  {
        if defined UTIL_SHBUS_ENABLED { util_shbus_rx_msg(). }
        wait 0.02.
    }
}

function util_shsys_decode_rx_msg {
    parameter sender.
    parameter recipient.
    parameter opcode.
    parameter data.

    if not opcode:startswith("SYS") {
        return.
    }

    if opcode:startswith("SYS_CB_OPEN") {
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

function util_shsys_do_action {
    parameter action_in.
    if action_in = "1" {
        toggle AG1.
    } else if action_in = "2" {
        toggle AG2.
    } else if action_in = "3" {
        toggle AG3.
    } else if action_in = "4" {
        toggle AG4.
    } else if action_in = "5" {
        toggle AG5.
    } else if action_in = "6" {
        toggle AG6.
    } else if action_in = "7" {
        toggle AG7.
    } else if action_in = "8" {
        toggle AG8.
    } else if action_in = "9" {
        toggle AG9.
    } else if action_in = "0" {
        toggle AG10.
    } else if action_in = "g" {
        toggle GEAR.
    } else if action_in = "r" {
        toggle RCS.
    } else if action_in = "t" {
        toggle SAS.
    } else if action_in = "u" {
        toggle LIGHTS.
    } else if action_in = "b" {
        toggle BRAKES.
    } else if action_in = "m" {
        toggle MAPVIEW.
    } else if action_in = " " {
        print "stage manually".
    // additional actions
    } else if action_in = "engine" {
        for i in main_engines {
            i:activate().
        }
    } else if action_in = "thrust_max" {
        for i in main_engines {
            set i:thrustlimit to 100.
        }
    } else if action_in = "thrust_min" {
        for i in main_engines {
            set i:thrustlimit to 0.
        }
    } else if action_in = "decouple" and not (decoupler = -1) {
        decoupler:getmodule("ModuleDecouple"):doevent("Decouple").
        set decoupler to -1.
    } else if action_in = "faring" {
        set SPIN_ON_FARING to false.
    } else if action_in = "reaction_wheels_activate" {
        reaction_wheels:getmodule("ModuleReactionWheel"):doaction("activate wheel", true).
    } else if action_in = "spinon_engine" {
        set SPIN_ON_ENGINE to true.
    } else if action_in = "spinon_decouple" {
        set SPIN_ON_DECOUPLER to true.
    } else if action_in = "spinon_faring" {
        set SPIN_ON_FARING to true.
    } else if action_in = "spinon_separate" {
        set SPIN_ON_SEPARATION to true.
    } else if action_in = "unspin_engine" {
        set SPIN_ON_ENGINE to false.
    } else if action_in = "unspin_decouple" {
        set SPIN_ON_DECOUPLER to false.
    } else if action_in = "unspin_faring" {
        set SPIN_ON_FARING to false.
    } else if action_in = "unspin_separate" {
        set SPIN_ON_SEPARATION to false.
    } else {
        print "could not do action " + action_in.
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
