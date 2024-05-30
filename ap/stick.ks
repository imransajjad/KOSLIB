
global AP_STICK_ENABLED is true.

local PARAM is get_param(readJson("param.json"), "AP_STICK", lexicon()).

local STICK_GAIN is get_param(PARAM, "STICK_GAIN", 3.0).
local SWAP_ROLL_YAW is get_param(PARAM, "SWAP_ROLL_YAW", false).

local omega_w is V(0,0,0).
local input_state is 0. // 0 na, 1 keys, 0.5 stick

local total_transitions is 0.
local last_time is 0.
local last_input is 0.
local function lpf_on_pwm{
    parameter new_input.

    if total_transitions >= 6 {

        if not (new_input = 1.0) {
            set last_time to time:seconds.
        }

        if (time:seconds > last_time + 0.5) {
            set total_transitions to 0.
        }
        return 0.075.
    } else {
        if not (last_input = new_input) {
            set total_transitions to total_transitions + 1.
            set last_time to time:seconds.
        }

        if (time:seconds > last_time + 0.25) {
            set total_transitions to 0.
        }
        set last_input to new_input.
        return 0.15.
    }
}

function ap_stick_w {
    parameter u1.
    parameter u2.
    parameter u3.
    
    if SWAP_ROLL_YAW {
        local temp is u3.
        set u3 to u2.
        set u2 to temp.
    }
    local sum_inputs is (u1+u2+u3).
    local max_inputs is max(max(abs(u1),abs(u2)),abs(u3)).

    if not (sum_inputs = 0) and (max_inputs = 1.0) and (mod(sum_inputs, 1.0) = 0) {
        set input_state to 1.0.
    } else if not (max_inputs = 1.0) and not (mod(sum_inputs, 1.0) = 0) {
        set input_state to 0.5.
    } else {
        // do nothing, retain previous.
    }

    if input_state = 1.0 {
        local LPF to lpf_on_pwm(max_inputs).
        set omega_w to (1-LPF)*omega_w + (LPF)*(V(sat(u1,1.0),sat(u2,1.0),sat(u3,1.0)))*(LPF/0.15)^2.
    } else {
        set omega_w to V(sat(STICK_GAIN*u1,1.0),sat(STICK_GAIN*u2,1.0),sat(STICK_GAIN*u3,1.0)).
    }
    return V(omega_w:x,omega_w:y,omega_w:z).
}
