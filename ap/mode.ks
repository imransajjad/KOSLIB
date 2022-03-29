
GLOBAL AP_MODE_ENABLED IS TRUE.
local PARAM is get_param(readJson("param.json"), "AP_MODE", lexicon()).

global LIST_AVAIL_AP_MODES is list().

set AP_MODE_PILOT_ENABLED to true.
// pilot mode is always available

set AP_MODE_VEL_ENABLED to get_param(PARAM,"VEL_ENABLED", false ).
set AP_MODE_NAV_ENABLED to get_param(PARAM,"NAV_ENABLED", false ).
set AP_MODE_NONE_ENABLED to get_param(PARAM,"NONE_ENABLED", false ).

// AP MODE STUFF

// USES AG

local lock AG to AG2.

global AP_MODE_PILOT is true.
global AP_MODE_VEL is false.
global AP_MODE_NAV is false.
global AP_MODE_NONE is false.

LIST_AVAIL_AP_MODES:add(AP_MODE_PILOT_ENABLED).
LIST_AVAIL_AP_MODES:add(AP_MODE_VEL_ENABLED).
LIST_AVAIL_AP_MODES:add(AP_MODE_NAV_ENABLED).
LIST_AVAIL_AP_MODES:add(AP_MODE_NONE_ENABLED).

local current_mode is 0.
local function go_to_next_mode {
    
    set AP_MODE_PILOT to false.
    set AP_MODE_VEL to false.
    set AP_MODE_NAV to false.
    set AP_MODE_NONE to false.

    set current_mode to current_mode+1.
    if current_mode >= LIST_AVAIL_AP_MODES:length {
        set current_mode to 0.
    }

    if LIST_AVAIL_AP_MODES[current_mode] {
        if current_mode = 0 {
            set AP_MODE_PILOT to true.
        } else if current_mode = 1 {
            set AP_MODE_VEL to true.
        } else if current_mode = 2 {
            set AP_MODE_NAV to true.
        } else if current_mode = 3 {
            set AP_MODE_NONE to true.
        }    
    } else {
        go_to_next_mode().
    }
}


local PREV_AG is AG.
function ap_mode_update {
    if (PREV_AG <> AG)
    {
        set PREV_AG to AG.
        go_to_next_mode().
        print "SWITCHED to AP_MODE_"+ap_mode_get_str().
    }
    if SAS {
        until AP_MODE_PILOT { go_to_next_mode(). }
    }
}

function ap_mode_set {
    parameter mode_str.
    if mode_str = "SAS" {
        SAS on.
    } else if AP_MODE_PILOT_ENABLED and (mode_str = "PILOT" or mode_str = "") {
        until AP_MODE_PILOT {
            go_to_next_mode().
        }
    } else if AP_MODE_NAV_ENABLED and mode_str = "NAV"{
        until AP_MODE_NAV {
            go_to_next_mode().
        }
    } else if AP_MODE_VEL_ENABLED and mode_str = "VEL"{
        until AP_MODE_VEL {
            go_to_next_mode().
        }
    } else if AP_MODE_NONE_ENABLED and mode_str = "NONE"{
        until AP_MODE_NONE {
            go_to_next_mode().
        }
    }
    if mode_str = ap_mode_get_str() {
        print "SWITCHED to AP_MODE_"+mode_str.
    } else {
        print "could not switch to AP_MODE_" + mode_str.
    }
}

function ap_mode_get_str{
    if SAS { return "SAS".}
    else if AP_MODE_PILOT { return "".}
    else if AP_MODE_NAV { return "NAV".}
    else if AP_MODE_VEL { return "VEL".}
    else if AP_MODE_NONE { return "N/A".}
    else { return "".}
}
