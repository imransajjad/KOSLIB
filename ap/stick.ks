
global AP_STICK_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_STICK", lexicon()).

local STICK_GAIN is get_param(PARAM, "STICK_GAIN", 3.0).
local KEYS_LPF is get_param(PARAM, "KEYS_LPF", 0.1).
local SWAP_ROLL_YAW is get_param(PARAM, "SWAP_ROLL_YAW", false).

local omega_w is V(0,0,0).
local input_state is 0. // 0 released, 1 keys, 0.5 stick

function ap_stick_w {
    parameter u1.
    parameter u2.
    parameter u3.
    
    if SWAP_ROLL_YAW {
        local temp is u3.
        set u3 to u2.
        set u2 to temp.
    }
    if not (input_state = 0.5) and (abs(u1) = 1 or abs(u2) = 1 or abs(u3) = 1) {
        set input_state to 1.0.
    } else if ((abs(u1) = 0 and abs(u2) = 0 and abs(u3) = 0)) {
        set input_state to 0.0.
    } else {
        set input_state to 0.5.
    }

    if input_state = 1.0 {
        set omega_w to (1-KEYS_LPF)*omega_w + (KEYS_LPF)*(V(sat(u1,1.0),sat(u2,1.0),sat(u3,1.0))).
    } else {
        set omega_w to V(sat(STICK_GAIN*u1,1.0),sat(STICK_GAIN*u2,1.0),sat(STICK_GAIN*u3,1.0)).
    }
    return V(omega_w:x,omega_w:y,omega_w:z).
}
