// al3 params

set UTIL_WP_takeoff_distance to 400.

// glimits
set AP_FLCS_ROT_GLIM_VERT to 2.
set AP_FLCS_ROT_GLIM_LAT to 1.
set AP_FLCS_ROT_GLIM_LONG to 5.

set AP_FLCS_CORNER_VELOCITY to 60.

set AP_FLCS_START_MASS to 85.9.

// rate limits
set AP_FLCS_MAX_ROLL to 0.5*3.14159265359.

// pitch rate PID gains
set AP_FLCS_ROT_PR_KP to 2.5.
set AP_FLCS_ROT_PR_KI to 3.1.
set AP_FLCS_ROT_PR_KD to 0.01.

// yaw rate PID gains
set AP_FLCS_ROT_YR_KP to 2.0.
set AP_FLCS_ROT_YR_KI to 0.0.
set AP_FLCS_ROT_YR_KD to 0.0.

// roll rate PID gains
//set AP_FLCS_ROT_RR_KP to 0.1.
//set AP_FLCS_ROT_RR_KI to 0.011.
//set AP_FLCS_ROT_RR_KD to 0.001.

// roll rate PID gains
set AP_FLCS_ROT_RR_KP to 0.15.
set AP_FLCS_ROT_RR_KI to 0.00.
set AP_FLCS_ROT_RR_KD to 0.00.

// pitch rate PID alternate gains
set AP_FLCS_ROT_PR_KP_ALT to 2.8.
set AP_FLCS_ROT_PR_KI_ALT to 10.0.
set AP_FLCS_ROT_PR_KD_ALT to 0.01.


// glimits
set AP_NAV_ROT_GNOM_VERT to 1.
set AP_NAV_ROT_GNOM_LAT to 0.1.
set AP_NAV_ROT_GNOM_LONG to 1.

set AP_NAV_K_PITCH to 0.05.
set AP_NAV_K_YAW to 0.08.
set AP_NAV_K_ROLL to 0.005.
set AP_NAV_K_HEADING to 4.5.
set AP_NAV_ROLL_W_MIN to 5.0.
set AP_NAV_ROLL_W_MAX to 20.0.
set AP_NAV_BANK_MAX to 90.
set AP_NAV_VSET_MAX to 350.


set AP_ENGINES_V_PID_KP to 0.025.
set AP_ENGINES_V_PID_KI to 0.0007.
set AP_ENGINES_V_PID_KD to 0.0.

// UTIL_HUD
set UTIL_HUD_START_COLOR to 4.
set UTIL_HUD_CAMERA_HEIGHT to 1.2.
set UTIL_HUD_CAMERA_RIGHT to -0.4.

set UTIL_HUD_LAND_GUIDE to true.
set UTIL_HUD_LADDER to true.
set UTIL_HUD_NAVVEC to true.

set UTIL_HUD_GSLOPE to 3.0.
set UTIL_HUD_GHEAD to 90.4.
set UTIL_HUD_PITCH_DIV to 5.0.
set UTIL_HUD_FLARE_ALT to 40.
set UTIL_HUD_SHIP_HEIGHT to 5.7.


// AP_MODE
set AP_MODE_FLCS_ENABLED to true.
set AP_MODE_VEL_ENABLED to true.
set AP_MODE_NAV_ENABLED to true.

set MAIN_ENGINE_NAME to "turboFanSize2".
