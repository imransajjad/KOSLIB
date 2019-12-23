// testing on fighter stealth 3

WAIT UNTIL SHIP:LOADED.
IF addons:available("RT") {
    WAIT UNTIL addons:RT:AVAILABLE.
    WAIT UNTIL addons:RT:HASKSCCONNECTION(SHIP).
}
ELSE {
    WAIT 3.
}

COPYPATH("0:/koslib/util/common.ks","util_common").
COPYPATH("0:/koslib/target/radar.ks","target_radar").

IF NOT (DEFINED TARGET_RADAR_ENABLED) { GLOBAL TARGET_RADAR_ENABLED IS false.}

run once "util_common".
run once "target_radar".



set KERBIN TO body("Kerbin").

set max_range to 100000.
set max_angle to 20.

set Ts to 1.0.
set scan_timeout_max to 10.

until false {
    target_radar_update_target().
    target_radar_draw_picture().
    wait Ts.
}
