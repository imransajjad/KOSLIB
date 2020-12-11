
GLOBAL UTIL_SHSYS_ENABLED IS true.

local PARAM is get_param(readJson("param.json"),"UTIL_SHSYS", lexicon()).

local MAIN_ANTENNAS_NAME is get_param(PARAM, "MAIN_ANTENNAS_NAME", "").
local AUX_ANTENNAS_NAME is get_param(PARAM, "AUX_ANTENNAS_NAME", "").
local ARM_RLAUNCH_STATUS is get_param(PARAM, "ARM_RLAUNCH_STATUS", "").

local ATMOS_ESCAPE_STAGE is get_param(PARAM, "ATMOS_ESCAPE_STAGE", 99999).
local ATMOS_ESCAPE_ALT is get_param(PARAM, "ATMOS_ESCAPE_ALT", 70000).

local REENTRY_STAGE is get_param(PARAM, "REENTRY_STAGE", 99999).
local REENTRY_ALT is get_param(PARAM, "REENTRY_ALT", 65000).
local PARACHUTE_ALT is get_param(PARAM, "PARACHUTE_ALT", 1000).

local Q_SAFE is get_param(PARAM, "Q_SAFE", 0).
local qsafe_last is true.

local MIN_SEPARATION is get_param(PARAM, "MIN_SEPARATION", 3).
local BAYS_DELAY is get_param(PARAM, "BAYS_DELAY", 0).
local TARGET_CACHING is get_param(PARAM, "TARGET_CACHING", true).

local dockingports is get_parts_tagged(get_param(PARAM, "DOCKING_PORT_NAME", "")).

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

local prev_status is "NA".
local prev_stage is 99999.
local arm_panels_and_antennas is false.
local arm_for_reentry is false.
local arm_parachutes is false.

local initial_ship is ship.

local SPIN_STATES to lexicon().
if exists("spin-states.json") {
    set SPIN_STATES to readJson("spin-states.json").
}

local SPIN_ON_ENGINE is get_param(SPIN_STATES, "SPIN_ON_ENGINE", false).
local SPIN_ON_DECOUPLER is get_param(SPIN_STATES, "SPIN_ON_DECOUPLER", false).
local SPIN_ON_DOCKINGPORT is get_param(SPIN_STATES, "SPIN_ON_DOCKINGPORT", false).
local SPIN_ON_FARING is get_param(SPIN_STATES, "SPIN_ON_FARING", false).
local SPIN_ON_SEPARATION is get_param(SPIN_STATES, "SPIN_ON_SEPARATION", false).
local SPIN_ON_REMOTE_BAYS is get_param(SPIN_STATES, "SPIN_ON_REMOTE_BAYS", false).

local function save_spin_states {
    set SPIN_STATES["SPIN_ON_ENGINE"] to SPIN_ON_ENGINE.
    set SPIN_STATES["SPIN_ON_DECOUPLER"] to SPIN_ON_DECOUPLER.
    set SPIN_STATES["SPIN_ON_DOCKINGPORT"] to SPIN_ON_DOCKINGPORT.
    set SPIN_STATES["SPIN_ON_FARING"] to SPIN_ON_FARING.
    set SPIN_STATES["SPIN_ON_SEPARATION"] to SPIN_ON_SEPARATION.
    set SPIN_STATES["SPIN_ON_REMOTE_BAYS"] to SPIN_ON_REMOTE_BAYS.
    writeJson(SPIN_STATES, "spin-states.json").
}


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
            for a in get_parts_tagged(MAIN_ANTENNAS_NAME) {
                a:GETMODULE("ModuleRTAntenna"):doaction("activate", true).
            }
            for a in get_parts_tagged(AUX_ANTENNAS_NAME) {
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
            for a in get_parts_tagged(MAIN_ANTENNAS_NAME) {
                a:GETMODULE("ModuleRTAntenna"):doaction("deactivate", true).
            }
            for a in get_parts_tagged(AUX_ANTENNAS_NAME) {
                a:GETMODULE("ModuleRTAntenna"):doaction("deactivate", true).
            }
        }
        if arm_parachutes and 
            (ship:altitude < (PARACHUTE_ALT- ship:geoposition:terrainheight)){
            set arm_parachutes to false.
            set CHUTES to true.
            print "SHSYS: CHUTES".
        }

        if not (prev_stage = STAGE:NUMBER) {
            if (STAGE:NUMBER = prev_stage - 1) {
                if defined UTIL_FLDR_ENABLED {
                    util_fldr_send_event("stage " + STAGE:NUMBER).
                }
            }
            set prev_stage to STAGE:NUMBER.
        }
    }
}

// these functions maintain a list of other ships and number of times
// the cargo bay has been opened. If other ships are within a certain distance
// or the cargo has been opened remotely but not closed, the cargo bay is opened
// otherwise it is closed, see cargo_bay_do()
local cargo_bay_opened_count is 0.
local other_ships is UNIQUESET().
local function add_another_ship {
    parameter namestr.
    list targets in target_list.

    for e in target_list {
        if e:name = namestr and not other_ships:contains(e){
            other_ships:add(e).
        }
    }
}

local function filter_other_ships {
    if other_ships:length > 0 {
        local oship_remove is 0.
        for oship in other_ships {
            if oship:distance > MIN_SEPARATION {
                set oship_remove to oship.
            }
        }
        if not (oship_remove = 0) {
            other_ships:remove(oship_remove).
            cargo_bay_do().
        }
    }
}

local function cargo_bay_do {
    if cargo_bay_opened_count = 0 and other_ships:length = 0 and BAYS {
        set BAYS to false.
        print "shsys closing BAYS".
    } else if (cargo_bay_opened_count > 0 or other_ships:length > 0) and not BAYS {
        set BAYS to true.
        print "shsys opening BAYS".
    }
}

local last_cargo_bay_ack_time is -1.
local function send_cargo_bay_delayed_ack {
    parameter sender.
    parameter delay.

    set last_cargo_bay_ack_time to time:seconds.
    when time:seconds > last_cargo_bay_ack_time + delay then {
        util_shbus_tx_msg("SYS_SET_SPIN", list("bays","false"), list(sender)).
        // print "sent delayed ack to " + sender + "from " + last_cargo_bay_ack_time.
        set last_cargo_bay_ack_time to -1.
    }
}

local function setup_docking {
    local target_vessel is util_shsys_get_target().

    if not ship:controlpart:hassuffix("UNDOCK") {
        if ship:dockingports:length > 0 {
            print "shsys controlling from docking port".
            ship:dockingports[0]:controlfrom().
            wait 0.5.
             if not (ship:controlpart:state = "Ready") and
                    ship:controlpart:hasmodule("ModuleAnimateGeneric") and
                    ship:controlpart:getmodule("ModuleAnimateGeneric"):hasaction("toggle shield") {
                // try opening the shield
                ship:controlpart:getmodule("ModuleAnimateGeneric"):doaction("toggle shield", true).
                wait 2.5.
            } else if not (ship:controlpart:state = "Ready") and
                    ship:controlpart:hasmodule("ModuleAnimateGeneric") and
                    ship:controlpart:getmodule("ModuleAnimateGeneric"):hasaction("toggle") {
                // try opening the shield
                ship:controlpart:getmodule("ModuleAnimateGeneric"):doaction("toggle", true).
                wait 2.5.
            }
    } else {
            print "shsys ship does not have a docking port".
            return.
        }
    }    
    // our control part should be a docking port now

    if target_vessel = -1 {
        print "no target".
        return.
    } else if target_vessel:position:mag > 200 {
        print "target needs to be within 200 m to set up docking".
        return.
    } else if target_vessel:hassuffix("dockingports") {
        for they in target_vessel:dockingports {
            if they:state = "Ready" and they:nodetype = ship:controlpart:nodetype {
               
                if ship:controlpart:state = "Ready" {
                    set TARGET to they.
                    print "target:dockingport".
                    return.
                }
            }
        }
    }
    print "shsys did not find compatible dockingport".
}

local target_vessel is -1.
local function cache_target {
    if TARGET_CACHING and ISACTIVEVESSEL and HASTARGET {
        if not (target_vessel = TARGET) {
            set target_vessel to TARGET.
            print "shsys target cached: "+ target_vessel:NAME.
        }
    } else if TARGET_CACHING and ISACTIVEVESSEL and not HASTARGET and not (target_vessel = -1) {
        set target_vessel to -1.
        print "shsys target uncached".
    }
}

function util_shsys_get_target {
    return target_vessel.
}

// main function for ship systems
// returns true if sys is not blocked.
local function shsys_check {
    parameter CLEANUP is false.

    local cur_wayp is -1.
    local try_wp is false.
    if defined UTIL_WP_ENABLED and (util_wp_queue_length() > 0) {
        set cur_wayp to util_wp_queue_first().
        set try_wp to true.
    }
    if try_wp and cur_wayp["mode"] = "act" {
            util_shsys_do_action(cur_wayp["do_action"]).
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event("action waypoint " + (util_wp_queue_length()-1)).
            }
            util_wp_done().
    } else if try_wp and cur_wayp["mode"] = "spin" {
            util_shsys_set_spin(cur_wayp["spin_part"], cur_wayp["spin_state"]).
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event("spin waypoint " + (util_wp_queue_length()-1)).
            }
            util_wp_done().
    }
    
    // check for fakely staged parts
    if SPIN_ON_ENGINE {
        if main_engines:length > 0 {
            set SPIN_ON_ENGINE to not main_engines[0]:ignition.
        } else {
            set SPIN_ON_ENGINE to false.
        }
        if not SPIN_ON_ENGINE { save_spin_states(). }
    }
    if SPIN_ON_DECOUPLER {
        local decoupler is core:part:decoupler.
        if not (decoupler = "None") {
            set SPIN_ON_DECOUPLER to decoupler:hasparent and decoupler:children:length > 0.
        } else {
            set SPIN_ON_DECOUPLER to false.
        }
        if not SPIN_ON_DECOUPLER { save_spin_states(). }
    }
    local any_docked is false.
    if SPIN_ON_DOCKINGPORT {
        for i in core:element:dockingports {
            set any_docked to any_docked or
                i:state:contains("Docked") or 
                i:state:contains("PreAttached").
        }
    }
    if SPIN_ON_FARING {
        set SPIN_ON_FARING to false. // not implemented yet
        if not SPIN_ON_FARING { save_spin_states(). }
    }
    if SPIN_ON_SEPARATION {
        if initial_ship:distance > MIN_SEPARATION {
            set SPIN_ON_SEPARATION to false.
        }
        if not SPIN_ON_SEPARATION { save_spin_states(). }
    }
    if SPIN_ON_REMOTE_BAYS {
        // can't do anything
    }
    local do_spin is (SPIN_ON_ENGINE or
                SPIN_ON_DECOUPLER or
                any_docked or
                SPIN_ON_FARING or
                SPIN_ON_SEPARATION or
                SPIN_ON_REMOTE_BAYS).

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
        } else if (not qsafe_last and (ship:q <= Q_SAFE)) {
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
    filter_other_ships().

    if TARGET_CACHING {
        cache_target().
    }

    iterate_spacecraft_system_state().

    if CLEANUP {
        print "shsys_check cleanup".
    }
    return not do_spin.
}

function util_shsys_spin_check {
    until shsys_check() {
        if defined UTIL_SHBUS_ENABLED {
            util_shbus_rx_msg().
        }
        if defined AP_ORB_ENABLED {
            ap_orb_lock_controls(false).
        }
        if defined UTIL_HUD_ENABLED {
            util_hud_setting("on",false).
            util_hud_info().
        }
        wait 0.02.
    }
}

function util_shsys_cleanup {
    if defined UTIL_HUD_ENABLED {
        util_hud_pop_left("shsys_q").
    } else if defined UTIL_SHBUS_ENABLED {
        util_shbus_tx_msg("HUD_POPL", list(core:tag+"shsys_q")).
    }
}

function util_shsys_decode_rx_msg {
    parameter sender.
    parameter recipient.
    parameter opcode.
    parameter data.

    if not opcode:startswith("SYS") {
        return false.
    }

    if opcode:startswith("SYS_CB_OPEN") {
        set cargo_bay_opened_count to max(0,cargo_bay_opened_count+1).
        cargo_bay_do().
        send_cargo_bay_delayed_ack(sender, BAYS_DELAY).
    } else if opcode = "SYS_CB_CLOSE" {
        set cargo_bay_opened_count to max(0,cargo_bay_opened_count-1).
        cargo_bay_do().
    } else if opcode = "SYS_PL_AWAY" {
        wait 0.
        wait 0.
        add_another_ship(data[0]).
        cargo_bay_do().
    } else if opcode = "SYS_DO_ACTION" {
        if data:length = 1 {
            util_shsys_do_action(data[0]).
        } else {
            print "usage util_shsys_do_action(action)".
        }
    } else if opcode = "SYS_SET_SPIN" {
        if data:length = 2 {
            util_shsys_set_spin(data[0],data[1]).
        } else {
            print "usage util_shsys_set_spin(part_name, set_state)".
        }
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
    } else if action_in = "decouple" {
        local decoupler is core:part:decoupler.
        if not (decoupler = "None") {
            decoupler:getmodule("ModuleDecouple"):doevent("Decouple").
        }
    } else if action_in = "reaction_wheels_activate" {
        local reaction_wheels is -1.
        set reaction_wheels to get_ancestor_with_module("ModuleReactionWheel").
        if (reaction_wheels = -1) { get_child_with_module("ModuleReactionWheel"). }
        reaction_wheels:getmodule("ModuleReactionWheel"):doaction("activate wheel", true).
    } else if action_in = "lock_target" {
        set TARGET_CACHING to false.
    } else if action_in = "get_target" {
        set TARGET_CACHING to true.
    } else if action_in = "dock_target" {
        setup_docking().
    } else {
        print "could not do action " + action_in.
        return false.
    }
    return true.
}

function util_shsys_set_spin {
    parameter part_name.
    parameter set_state.

    if set_state = "true" {
        set set_state to true.
    } else if set_state = "false" {
        set set_state to false.
    } else {
        print "set_state not valid".
        return true.
    }
    if part_name = "engine" {
        set SPIN_ON_ENGINE to set_state.
    } else if part_name = "decoupler" {
        set SPIN_ON_DECOUPLER to set_state.
    } else if part_name = "faring" {
        set SPIN_ON_FARING to set_state.
    } else if part_name = "separate" {
        set SPIN_ON_SEPARATION to set_state.
    } else if part_name = "dock" {
        set SPIN_ON_DOCKINGPORT to set_state.
    } else if part_name = "bays" {
        set SPIN_ON_REMOTE_BAYS to set_state.
    } else {
        print "could not find " + part_name.
        return false.
    }
    save_spin_states().
    print "spin on " + part_name + " set to " + set_state.
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
    if RCS {
        stat_list:add("R").
    }
    return stat_list:join("").
}
