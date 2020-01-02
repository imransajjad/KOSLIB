// fs3 params

set UTIL_WP_landing_sequence to LIST(
        //list(-1, 1000,150, -0.3,-74.5),
        list(-1, 1000,150, -0.45,-74.95),
        list(-1, 500,100,  -0.15,-75.25,-10,0.0),
        list(-1, 250,60,   -0.0485911247,-75.02,-5.0,90.4),
        list(-1, -2),
        list(-1, 75,60,    -0.0485911247,-74.73766837,-2.5,90.4),
        list(-1, 70,0,    -0.049359350,-74.625860287-0.01,-0.05,90.4),
        list(-1, -1)). // brakes

set UTIL_WP_takeoff_distance to 400.

// glimits
set AP_FLCS_ROT_GLIM_VERT to 12.
set AP_FLCS_ROT_GLIM_LAT to 6.
set AP_FLCS_ROT_GLIM_LONG to 5.

// cor

// pitch rate PID gains
set AP_FLCS_ROT_PR_KP to 0.8.
set AP_FLCS_ROT_PR_KI to 0.9.
set AP_FLCS_ROT_PR_KD to 0.01.

// yaw rate PID gains
set AP_FLCS_ROT_YR_KP to 1.0.
set AP_FLCS_ROT_YR_KI to 0.0.
set AP_FLCS_ROT_YR_KD to 0.0.

// roll rate PID gains
//set AP_FLCS_ROT_RR_KP to 0.1.
//set AP_FLCS_ROT_RR_KI to 0.011.
//set AP_FLCS_ROT_RR_KD to 0.001.

// roll rate PID gains
set AP_FLCS_ROT_RR_KP to 0.1.
set AP_FLCS_ROT_RR_KI to 0.02.
set AP_FLCS_ROT_RR_KD to 0.00.

// pitch rate PID alternate gains
set AP_FLCS_ROT_PR_KP_ALT to 2.8.
set AP_FLCS_ROT_PR_KI_ALT to 10.0.
set AP_FLCS_ROT_PR_KD_ALT to 0.01.


set AP_NAV_K_PITCH to 0.025.
set AP_NAV_K_YAW to 0.03.
set AP_NAV_K_ROLL to 0.003.
set AP_NAV_K_HEADING to 4.5.
set AP_NAV_ROLL_W_MIN to 10.0.
set AP_NAV_ROLL_W_MAX to 20.0.
set AP_NAV_BANK_MAX to 90.


