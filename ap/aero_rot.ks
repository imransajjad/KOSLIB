
GLOBAL AP_AERO_ROT_ENABLED IS true.

local PARAM is readJson("param.json")["AP_AERO_ROT"].

local STICK_GAIN is get_param(PARAM, "STICK_GAIN", 3.0).

// glimits
local GLIM_VERT is get_param(PARAM,"GLIM_VERT", 5).
local GLIM_LAT is get_param(PARAM,"GLIM_LAT", 1).
local GLIM_LONG is get_param(PARAM,"GLIM_LONG", 3).

local CORNER_VELOCITY is get_param(PARAM,"CORNER_VELOCITY", 200).


local RATE_SCHEDULE_ENABLED is get_param(PARAM, "RATE_SCHEDULE_ENABLED", false).
local START_MASS is get_param(PARAM,"START_MASS", 0).

local GAIN_SCHEDULE_ENABLED is get_param(PARAM,"GAIN_SCHEDULE_ENABLED", false).
local PITCH_SPECIFIC_INERTIA is get_param(PARAM,"PITCH_SPECIFIC_INERTIA", 0).

local USE_GCAS is get_param(PARAM, "USE_GCAS", false).
local GCAS_MARGIN is get_param(PARAM, "GCAS_MARGIN").
local GCAS_GAIN_MULTIPLIER is get_param(PARAM, "GCAS_GAIN_MULTIPLIER").

// rate limits
local MAX_ROLL is DEG2RAD*get_param(PARAM,"MAX_ROLL", 180).

// pitch rate PID gains
local PR_KP is get_param(PARAM,"PR_KP", 0).
local PR_KI is get_param(PARAM,"PR_KI", 0).
local PR_KD is get_param(PARAM,"PR_KD", 0).

// yaw rate PID gains
local YR_KP is get_param(PARAM,"YR_KP", 0).
local YR_KI is get_param(PARAM,"YR_KI", 0).
local YR_KD is get_param(PARAM,"YR_KD", 0).

// roll rate PID gains
local RR_KP is get_param(PARAM,"RR_KP", 0).
local RR_KI is get_param(PARAM,"RR_KI", 0).
local RR_KD is get_param(PARAM,"RR_KD", 0).
local RR_I_SAT is get_param(PARAM, "RR_I_SAT", 0.05).

// nav angle difference gains
local K_PITCH is get_param(PARAM,"K_PITCH").
local K_YAW is get_param(PARAM,"K_YAW").
local K_ROLL is get_param(PARAM,"K_ROLL").

// USES AG6

local lock AG to AG6.

// AERO ROT PID STUFF

local lock vel to ship:airspeed.

local lock wg to vcrs(ship:velocity:surface:normalized, ship:up:vector)*
                (get_frame_accel_orbit()/max(1,vel)):mag.

local lock pitch_rate to -((SHIP:ANGULARVEL)*SHIP:FACING:STARVECTOR).
local lock yaw_rate to ((SHIP:ANGULARVEL+wg)*SHIP:FACING:TOPVECTOR).
local lock roll_rate to -((SHIP:ANGULARVEL)*SHIP:FACING:FOREVECTOR).


local lock LATOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:STARVECTOR.
local lock LONGOFS to (SHIP:POSITION-SHIP:CONTROLPART:POSITION)*SHIP:FACING:VECTOR.

local lock ship_vel to (-SHIP:FACING)*ship:velocity:surface:direction.
local lock alpha to wrap_angle(ship_vel:pitch).
local lock beta to wrap_angle(-ship_vel:yaw).

local function cl_sched {
    parameter v.

    if ( v < 100) {
        return -(5/100)*v + 8.5.
    } else if (v < 300) {
        return -(2.5/200)*v + 4.75.
    } else if (v < 2100) {
        return -(0.2/700)*v + 1.09.
    } else {
        return 0.49.
    }
}

local function cd_sched {
    parameter v.

    if (v < 50) {
        return 1.0.
    } else if ( v < 100) {
        return -(0.5/50)*v + 1.5.
    } else if (v < 300) {
        return 0.5.
    } else if (v < 400) {
        return (1.0/100)*v - 2.5.
    } else if (v < 500) {
        return -(0.3/100)*v + 2.7.
    } else {
        return 1.2.
    }
}

local MIN_AERO_Q is 0.0003.
local MIN_PITCH_RATE is 2.5*DEG2RAD.

local MIN_SEA_Q is 1.0*(50/420)^2.
local CORNER_SEA_Q is 1.0*(CORNER_VELOCITY/420)^2.
local W_V_MAX is (GLIM_VERT*g0/CORNER_VELOCITY).
local W_L_MAX is (GLIM_LAT*g0/CORNER_VELOCITY).

local WING_AREA is 0.

local lock GLimiter to ( prate_max+0.0001 + g0/vel*cos(vel_pitch)*cos(roll) >
    GLIM_VERT*g0/vel ).

local pratePID is PIDLOOP(
    PR_KP,
    PR_KI,
    PR_KD,
    -1.0,1.0).
local pitch_rate is 0.
if (RATE_SCHEDULE_ENABLED)
{
    set WING_AREA to W_V_MAX/
            (CORNER_SEA_Q*cl_sched(CORNER_VELOCITY))
            *(START_MASS*CORNER_VELOCITY).
    lock prate_max to 
        max(
            MIN_PITCH_RATE,
            min(
                WING_AREA*SHIP:DYNAMICPRESSURE*cl_sched(vel)/(ship:mass*vel),
                GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
} else {
    lock prate_max to max(
            MIN_PITCH_RATE,
            min(
                (vel/CORNER_VELOCITY)*W_V_MAX,
                GLIM_VERT*g0/vel
                ) - g0/vel*cos(vel_pitch)*cos(roll)
            ).
}

local yratePID is PIDLOOP(
    YR_KP,
    YR_KI,
    YR_KD,
    -1.0,1.0).
local lock yrate_max to MIN(
    W_L_MAX*sqrt(SHIP:DYNAMICPRESSURE/CORNER_SEA_Q),
    GLIM_LAT*g0/vel).

local rratePD is PIDLOOP(
    RR_KP,
    0,
    RR_KD,
    -1.0,1.0).

local rrateI is PIDLOOP(
    0,
    RR_KI,
    0,
    -RR_I_SAT,RR_I_SAT).

local lock rrate_max to sat(vel/CORNER_VELOCITY*MAX_ROLL, MAX_ROLL).


local LF2G is 1.0.
local prev_AG is AG.
local function gain_schedule {

    local loadfactor is max(ship:q,MIN_SEA_Q)/ship:mass.
    local alsat is sat(alpha,35).
    local airflow_c_u is cl_sched(max(50,vel))*(cos(alsat)^3 - 1*cos(alsat)*sin(alsat)^2)+
        cd_sched(max(50,vel))*(2*cos(alsat)*sin(alsat)^2).

    set LF2G to 1.0.

    if prev_AG <> AG {
        set prev_AG to AG.
        print "LF2G: " + round_dec(LF2G/(choose 3 if AG else 1),2).
    }
    if prev_AG {
        set LF2G to LF2G/3.
    }
    set LF2G to LF2G/(PITCH_SPECIFIC_INERTIA*loadfactor*airflow_c_u)/kuniverse:timewarp:rate.

    set pratePID:KP to PR_KP*LF2G.
    set pratePID:KI to PR_KI*LF2G.
    set pratePID:KD to PR_KD*LF2G.

    set yratePID:KP to YR_KP*LF2G.
    set yratePID:KI to YR_KI*LF2G.
    set yratePID:KD to YR_KD*LF2G.
    
    set rratePD:KP to RR_KP*LF2G.
    set rrateI:KI to RR_KI*LF2G.
    set rratePD:KD to RR_KD*LF2G.
}


local Vslast is 0.0.
local prev_land is SHIP:STATUS.
local function display_land_stats {
    if not (SHIP:STATUS = prev_land) {
        if SHIP:STATUS = "LANDED" {
            local land_stats is "landed" + char(10) +
                "  pitch "+ round_dec(pitch,2) + char(10) +
                "  v/vs  "+ round_dec(vel,2) + "/"+round_dec(Vslast,2).
            if defined UTIL_HUD_ENABLED {
                util_hud_push_left("AERO_ROT_LAND_STATS" , land_stats ).
            }
            if defined UTIL_FLDR_ENABLED {
                util_fldr_send_event(land_stats).
            }
            print land_stats.
        } else if SHIP:STATUS = "FLYING" {
            if defined UTIL_HUD_ENABLED {
                util_hud_pop_left("AERO_ROT_LAND_STATS").
            }
        }
        set prev_land to SHIP:STATUS.
    }
    if ship:status = "FLYING" {
        SET Vslast TO SHIP:VERTICALSPEED.
    }
}


local aero_active is true.
function ap_aero_rot_do {
    parameter u1 is SHIP:CONTROL:PILOTPITCH. // pitch
    parameter u2 is SHIP:CONTROL:PILOTYAW. // yaw
    parameter u3 is SHIP:CONTROL:PILOTROLL. // roll in radians/sec
    parameter direct_mode is false.
    // in direct_mode, u1,u2,u3 are expected to be direct rate values
    // else they are stick inputs


    if not SAS and ship:q > MIN_AERO_Q {

        display_land_stats().
        if GAIN_SCHEDULE_ENABLED {
            gain_schedule().
        }
        if USE_GCAS and gcas_check() {
            set pratePID:SETPOINT TO sat(GCAS_GAIN_MULTIPLIER*K_PITCH*DEG2RAD*(gcas_escape_pitch-vel_pitch)*cos(roll),prate_max).
            set yratePID:SETPOINT TO 0.0.
            set rratePD:SETPOINT TO sat(GCAS_GAIN_MULTIPLIER*K_ROLL*DEG2RAD*(-roll),rrate_max).
            set rrateI:SETPOINT TO sat(GCAS_GAIN_MULTIPLIER*K_ROLL*DEG2RAD*(-roll),rrate_max).
        } else if direct_mode {
            set pratePID:SETPOINT TO sat(u1,prate_max).
            set yratePID:SETPOINT TO sat(u2,yrate_max).
            set rratePD:SETPOINT TO sat(u3,rrate_max).
            set rrateI:SETPOINT TO sat(u3,rrate_max).
        } else {
            set pratePID:SETPOINT TO prate_max*sat(STICK_GAIN*u1,1.0).
            set yratePID:SETPOINT TO yrate_max*sat(STICK_GAIN*u2,1.0).
            set rratePD:SETPOINT TO rrate_max*sat(STICK_GAIN*u3,1.0).
            set rrateI:SETPOINT TO rrate_max*sat(STICK_GAIN*u3,1.0).
        }

        set SHIP:CONTROL:YAW TO yratePID:UPDATE(TIME:SECONDS, yaw_rate)
            +SHIP:CONTROL:YAWTRIM.

        local roll_pd is rratePD:UPDATE(TIME:SECONDS, roll_rate).
        local roll_i is 0.
        if (abs(u3) < 0.2) {
            set roll_i to rrateI:UPDATE(TIME:SECONDS, roll_rate).
        } else {
            rrateI:RESET().
        }

        set SHIP:CONTROL:ROLL TO ( roll_pd + roll_i ) +
            SHIP:CONTROL:ROLLTRIM.

        set SHIP:CONTROL:PITCH TO pratePID:UPDATE(TIME:SECONDS, pitch_rate)+
            SHIP:CONTROL:PITCHTRIM.

        if not aero_active {
            set aero_active to true.
        }
    } else {
        if aero_active {
            set aero_active to false.
            rrateI:RESET().
            yratePID:RESET().
            pratePID:RESET().
            SET SHIP:CONTROL:NEUTRALIZE to TRUE.
        }
    }
}

local function gcas_vector_impact {
    parameter impact_vector.
    local sticky_factor is 2.0.

    local impact_distance is impact_vector*heading(vel_bear,0):vector.
    local impact_latlng is haversine_latlng(ship:geoposition:lat, ship:geoposition:lng,
            vel_bear ,RAD2DEG*impact_distance/ship:body:radius ).
    local impact_alt is max(latlng(impact_latlng[0],impact_latlng[1]):terrainheight,0).
    return (ship:altitude+impact_vector*ship:up:vector < 
        impact_alt+GCAS_MARGIN + (choose sticky_factor*GCAS_MARGIN if GCAS_ACTIVE else 0)).
}

local GCAS_ARMED is false.
local GCAS_ACTIVE is false.
local n_impact_pts is 5.
local straight_vector is V(0,0,0).
local impact_vector is V(0,0,0).
local gcas_escape_pitch is 0.0.

local function gcas_check {
    // ground collision avoidance system
    local escape_pitch is 10+max(0,vel_pitch).
    local escape_bear is vel_bear.
    local react_time is 1.0.

    if not GEAR and not SAS {
        local gcas_prate to max(RAD2DEG*prate_max/1.0,1.0).
        local gcas_yrate to max(RAD2DEG*yrate_max,1.0).
        local gcas_rrate to max(RAD2DEG*rrate_max/6.0,1.0).

        local t_preroll is abs(roll/gcas_rrate) + react_time.
        local vel_pitch_up is min(90,max(0,-vel_pitch+escape_pitch)).
        local t_pitch is abs(vel_pitch_up/gcas_prate).

        set straight_vector to
                ship:srfprograde:forevector*( (t_pitch + t_preroll)*ship:airspeed ).
        set impact_vector to 
                ship:srfprograde:forevector*( ship:airspeed/(DEG2RAD*gcas_prate)*sin(vel_pitch_up) + t_preroll*ship:airspeed ) +
                ship:srfprograde:topvector*( ship:airspeed/(DEG2RAD*gcas_prate)*(1-cos(vel_pitch_up))).

        if not GCAS_ARMED {
            if gcas_vector_impact(straight_vector) {
                set GCAS_ARMED to true.
                if defined UTIL_HUD_ENABLED { util_hud_push_right("AERO_ROT_GCAS", "GCAS").}
                print "GCAS armed".
            }
        } else if GCAS_ARMED {
            local impact_condition is false.
            for i in range(0,n_impact_pts) {
                set impact_condition to impact_condition or gcas_vector_impact(((i+1)/n_impact_pts)*impact_vector).
            }

            if not GCAS_ACTIVE and impact_condition {
                // GCAS is active here, will put in NAV mode after setting headings etc
                set GCAS_ACTIVE to true.
                if defined UTIL_HUD_ENABLED { util_hud_push_right("AERO_ROT_GCAS", "GCAS"+char(10)+"ACTIVE").}
                print "GCAS ACTIVE".
                set escape_bear to vel_bear.

            } else if GCAS_ACTIVE and not impact_condition {
                print "GCAS INACTIVE".
                if defined UTIL_HUD_ENABLED { util_hud_push_right("AERO_ROT_GCAS", "GCAS").}
                set GCAS_ACTIVE to false.
            }

            if GCAS_ACTIVE {
                set gcas_escape_pitch to escape_pitch.
                if (ship:altitude - GCAS_MARGIN < max(ship:geoposition:terrainheight,0))
                {
                    print "GCAS FLOOR BREACHED".
                    if defined UTIL_HUD_ENABLED { util_hud_push_right("AERO_ROT_GCAS", "GCAS"+char(10)+"BREACHED").}
                }
            }

            if not GCAS_ACTIVE and not gcas_vector_impact(straight_vector) {
                if defined UTIL_HUD_ENABLED { util_hud_pop_right("AERO_ROT_GCAS").}
                print "GCAS disarmed".
                set GCAS_ARMED to false.
            }
        }
    } else if GCAS_ARMED or GCAS_ACTIVE {
        // if GEAR or SAS, undo everything
        if defined UTIL_HUD_ENABLED { util_hud_pop_right("AERO_ROT_GCAS").}
        set GCAS_ARMED to false.
        set GCAS_ACTIVE to false.
    }
    return GCAS_ACTIVE.
}

function ap_aero_rot_gcas_check {
    return GCAS_ACTIVE.
}

// this function takes the desired NAV direction and finds
// an angular velocity to supply to the flcs. 
//  mostly it's just omega = K(NAV_DIR - prograde) + omega_ff 
function ap_aero_rot_nav_do {
    parameter vel_vec.
    parameter acc_vec.
    parameter head_dir.

    // a roll command is found as follows:
    // pitch errors and yaw errors are found in the ship frame
    // the omega required to overcome gravity pitching down plus 
    // the feed forward rates are also expressed in the ship frame.
    // we now have a omega that we have to "apply", but without any roll
    // 
    // this omega is fed to the haversine and we get a bearing and magnitude
    // like information about the pitch and yaw components of omega. Then
    // omega_roll = -K*have_roll_pre[0]
    // uses roll to minimze the bearing in the ship frame so that most omega is
    // applied by pitch and not by yaw

    unlock steering. // steering manager needs to be disabled.

    local current_nav_velocity is ship:velocity:surface.
    local w_g is vcrs(current_nav_velocity:normalized, ship:up:vector)*
                (get_frame_accel_orbit()/max(1,ship:airspeed)*RAD2DEG):mag.

    local wff is -vcrs(vel_vec,acc_vec):normalized*(acc_vec:mag/max(0.0001,vel_vec:mag))*RAD2DEG.

    local cur_pro is (-ship:facing)*current_nav_velocity:direction.
    local target_pro is (-ship:facing)*vel_vec:direction.

    local ship_frame_error is 
        V(-wrap_angle(target_pro:pitch-cur_pro:pitch),
        wrap_angle(target_pro:yaw-cur_pro:yaw),
        0 ).

    local WGM is 1.0/kuniverse:timewarp:rate.

    // omega applied by us
    local w_us is wff + WGM*K_PITCH*ship_frame_error:x*ship:facing:starvector +
                            -WGM*K_YAW*ship_frame_error:y*ship:facing:topvector.
    
    // omega applied by us including gravity for deciding roll
    local w_us_w_g is w_us-w_g.
    
    // util_hud_push_right("nav_w", "w_ff: (p,y): " + round_dec(wff*ship:facing:starvector,2) + "," + round_dec(-wff*ship:facing:topvector,2) +
    //     char(10)+ "w_g: (p,y): " + round_dec(w_g*ship:facing:starvector,2) + "," + round_dec(-w_g*ship:facing:topvector,2) +
    //     char(10)+ "w_us: (p,y): " + round_dec(w_us*ship:facing:starvector,2) + "," + round_dec(-w_us*ship:facing:topvector,2)).
    
    local have_roll_pre is haversine(0,0,w_us_w_g*ship:facing:starvector, -w_us_w_g*ship:facing:topvector).
    local roll_w is sat(have_roll_pre[1]/2.5,1.0).

    if ship:status = "LANDED" {
        set roll_w to 0.
    }

    local p_rot is w_us*ship:facing:starvector.
    local y_rot is -w_us*ship:facing:topvector.
    local r_rot is K_ROLL*convex(0-roll, wrap_angle(have_roll_pre[0]), roll_w).

    // util_hud_push_right("nav_w", ""+ round_dec(w_us*ship:facing:starvector,3) +
    //                             char(10)+round_dec(-w_us*ship:facing:topvector,3) +
    //                             char(10)+round_dec(w_us*ship:facing:forevector,3) +
    //                             char(10)+"rt:"+round_dec(have_roll_pre[0],1)).

    ap_aero_rot_do(DEG2RAD*p_rot, DEG2RAD*y_rot, DEG2RAD*r_rot ,true).
}

local departure is false.
function ap_aero_rot_status_string {

    local hud_str is "".

    if (ship:q > MIN_AERO_Q) {
        set hud_str to hud_str+( choose "GL " if GLimiter else "G ") +round_dec( vel*pitch_rate/g0 + 1.0*cos(vel_pitch)*cos(roll) ,1) + 
        char(10) + char(945) + " " + round_dec(alpha,1).
        if defined UTIL_FLDR_ENABLED {
            if abs(alpha) > 45 and not departure {
                util_fldr_send_event("aero_rot departure").
                set departure to true.
            } else if abs(alpha) < 20 and departure {
                set departure to false.
            }
        }
    }

    if ( false) { // pitch debug
    set hud_str to hud_str+
        char(10) + "ppid" + " " + round_dec(PR_KP,2) + " " + round_dec(PR_KI,2) + " " + round_dec(PR_KD,2) +
        char(10) + "pmax" + " " + round_dec(RAD2DEG*prate_max,1) +
        char(10) + "pask" + " " + round_dec(RAD2DEG*pratePID:SETPOINT,1) +
        char(10) + "pact" + " " + round_dec(RAD2DEG*pitch_rate,1) +
        char(10) + "perr" + " " + round_dec(RAD2DEG*pratePID:ERROR,1).
    }

    if ( false) { // roll debug
    set hud_str to hud_str+
        char(10) + "rpid" + " " + round_dec(RR_KP,2) + " " + round_dec(RR_KI,2) + " " + round_dec(RR_KD,2) +
        char(10) + "rmax" + " " + round_dec(RAD2DEG*rrate_max,1) +
        char(10) + "rask" + " " + round_dec(RAD2DEG*rratePD:SETPOINT,1) +
        char(10) + "ract" + " " + round_dec(RAD2DEG*roll_rate,1) +
        char(10) + "rerr" + " " + round_dec(RAD2DEG*rratePD:ERROR,1).
    }

    if ( false) { // yaw debug
    set hud_str to hud_str+
        char(10) + "ypid" + " " + round_dec(YR_KP,2) + " " + round_dec(YR_KI,2) + " " + round_dec(YR_KD,2) +
        char(10) + "ymax" + " " + round_dec(RAD2DEG*yrate_max,1) +
        char(10) + "yask" + " " + round_dec(RAD2DEG*yratePID:SETPOINT,1) +
        char(10) + "yact" + " " + round_dec(RAD2DEG*yaw_rate,1) +
        char(10) + "yerr" + " " + round_dec(RAD2DEG*yratePID:ERROR,1).
    }

    if ( false) { // q debug
    set hud_str to hud_str+
        char(10) + "q " + round_dec(ship:DYNAMICPRESSURE,7) +
        char(10) + "LF2G " + round_dec(LF2G,3) +
        char(10) + "WA " + round_dec(WING_AREA,1).
    }
    if ( false) { // nav debug
        set hud_str to hud_str+ char(10)+ "NAV_K " + round_dec(K_PITCH,5) + 
                                  char(10)+    "     " + round_dec(K_YAW,5) + 
                                  char(10)+    "     " + round_dec(K_ROLL,5).
    }

    return hud_str.
}
