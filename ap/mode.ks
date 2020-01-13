
GLOBAL AP_MODE_ENABLED IS TRUE.

// AP MODE STUFF

// USES AG

local lock AG to AG2.

local AP_FLCS is TRUE.
local AP_VEL is FALSE.
local AP_NAV is FALSE.
local AP_NONE is FALSE.
local PREV_AG is AG.
function ap_mode_update {
    if (PREV_AG <> AG)
    {
        set PREV_AG to AG.
        if AP_FLCS {
            set AP_FLCS to FALSE. set AP_VEL to TRUE.
        } else if AP_VEL {
            set AP_VEL to FALSE. set AP_NAV to TRUE.
        } else if AP_NAV {
            set AP_NAV to FALSE. set AP_FLCS to TRUE.
        } else if AP_NONE {
            set AP_NONE to FALSE. set AP_FLCS to TRUE.
        }
        print "SWITCHED to AP_"+ap_mode_get_str().
    }
}

function ap_mode_get_str{
    if SAS { return "SAS".}
    else if AP_FLCS { return "FLCS".}
    else if AP_NAV { return "NAV".}
    else if AP_VEL { return "VEL".}
    else if AP_NONE { return "N/A".}
}

function AP_SAS_CHECK {
    return SAS.
}

function AP_FLCS_CHECK {
    return AP_FLCS.
}

function AP_VEL_CHECK {
    return AP_VEL.
}

function AP_NAV_CHECK {
    return AP_NAV.
}

function AP_NONE_CHECK {
    return AP_NONE.
}
