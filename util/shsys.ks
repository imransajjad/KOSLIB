
GLOBAL UTIL_SHSYS_ENABLED IS true.

set cargo_bay_opened_count to 0.
set other_ships to UNIQUESET().

local MAIN_ENGINES is get_engines(main_engine_name).

local function get_another_ship {
    parameter namestr.
    list targets in target_list.
    local found is false.

    until found {
        for e in target_list {
            if e:name = namestr and not other_ships:contains(e){
                other_ships:add(e).
                set found to true.
            }
        }
    }
}

function util_shsys_decode_rx_msg {
    parameter received.

    set opcode to received:content[0].
    if not opcode:startswith("SYS") {
        return.
    } else if received:content:length > 1 {
        set data to received:content[1].
    }

    IF opcode:startswith("SYS_CB_OPEN") {
        set cargo_bay_opened_count to cargo_bay_opened_count + 1.
        set bays to true.
    } ELSE IF opcode = "SYS_CB_CLOSE" {
        set bays to false.
    } ELSE IF opcode = "SYS_PL_AWAY" {
        wait 0.1.
        get_another_ship(ship:name+" Probe").
    } else {
        print "could not decode shsys rx msg".
        return false.
    }
    return true.
}

function util_shsys_check {
    if cargo_bay_opened_count > 0 and not bays {
        set bays to true.
    } else if cargo_bay_opened_count = 0 and bays {
        set bays to false.
    }

    if other_ships:length > 0 {
        local oship_remove is 0.
        for oship in other_ships {
            if oship:distance > 3 {
                set oship_remove to oship.
            }
        }
        if not (oship_remove = 0) {
            set cargo_bay_opened_count to cargo_bay_opened_count-1.
            other_ships:remove(oship_remove).
        }
    }
}

function util_shsys_status_string {
    local stat_list is list().
    for me in MAIN_ENGINES {
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