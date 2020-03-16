// fs3 params

set UTIL_WP_takeoff_distance to 400.

// glimits
set AP_FLCS_ROT_GLIM_VERT to 12.
set AP_FLCS_ROT_GLIM_LAT to 9.
set AP_FLCS_ROT_GLIM_LONG to 5.

set AP_FLCS_CORNER_VELOCITY to 145.


set AP_FLCS_RATE_SCHEDULE_ENABLED to true.
set AP_FLCS_START_MASS to 8.3.

set AP_FLCS_GAIN_SCHEDULE_ENABLED to true.
set AP_FLCS_PITCH_SPECIFIC_INERTIA to 28.

// rate limits
set AP_FLCS_MAX_ROLL to 3.5*3.14159265359.

// pitch rate PID gains
set AP_FLCS_ROT_PR_KP to 1.4.
set AP_FLCS_ROT_PR_KI to 2.4.
set AP_FLCS_ROT_PR_KD to 0.1.

// yaw rate PID gains
set AP_FLCS_ROT_YR_KP to 1.5.
set AP_FLCS_ROT_YR_KI to 0.0.
set AP_FLCS_ROT_YR_KD to 0.0.

// roll rate PID gains
set AP_FLCS_ROT_RR_KP to 0.05.
set AP_FLCS_ROT_RR_KI to 0.01.
set AP_FLCS_ROT_RR_KD to 0.02.

// pitch rate PID alternate gains
set AP_FLCS_ROT_PR_KP_ALT to 2.0.
set AP_FLCS_ROT_PR_KI_ALT to 2.4.
set AP_FLCS_ROT_PR_KD_ALT to 0.1.


// glimits
set AP_NAV_ROT_GNOM_VERT to 0.5.
set AP_NAV_ROT_GNOM_LAT to 0.5.
set AP_NAV_ROT_GNOM_LONG to 1.

set AP_NAV_K_PITCH to 0.05.
set AP_NAV_K_YAW to 0.08.
set AP_NAV_K_ROLL to 0.0025.
set AP_NAV_K_HEADING to 2.5.
set AP_NAV_ROLL_W_MIN to 5.0.
set AP_NAV_ROLL_W_MAX to 20.0.
set AP_NAV_BANK_MAX to 90.
set AP_NAV_VSET_MAX to 850.


set AP_ENGINES_TOGGLE_X to 0.80.
set AP_ENGINES_TOGGLE_Y to 0.5.
set AP_ENGINES_TOGGLE_VEL to 345.
set AP_ENGINES_V_PID_KP to 0.075.
set AP_ENGINES_V_PID_KI to 0.01.
set AP_ENGINES_V_PID_KD to 0.0.

// UTIL_HUD
set UTIL_HUD_START_COLOR to 4.
set UTIL_HUD_CAMERA_HEIGHT to 0.83.
set UTIL_HUD_CAMERA_RIGHT to 0.0.

set UTIL_HUD_LAND_GUIDE to true.
set UTIL_HUD_LADDER to true.
set UTIL_HUD_NAVVEC to true.

set UTIL_HUD_GSLOPE to 2.5.
set UTIL_HUD_GHEAD to 90.4.
set UTIL_HUD_PITCH_DIV to 5.0.
set UTIL_HUD_FLARE_ALT to 15.0.
set UTIL_HUD_SHIP_HEIGHT to 1.65.

// AP_MODE
set AP_MODE_FLCS_ENABLED to true.
set AP_MODE_NAV_ENABLED to true.