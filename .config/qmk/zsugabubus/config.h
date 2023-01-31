#pragma once

#undef MOUSEKEY_MAX_SPEED
#define MOUSEKEY_MAX_SPEED 5

#undef MOUSEKEY_WHEEL_INTERVAL
#define MOUSEKEY_WHEEL_INTERVAL 60

#undef MOUSEKEY_WHEEL_DELAY
#define MOUSEKEY_WHEEL_DELAY MOUSEKEY_WHEEL_INTERVAL

#undef MOUSEKEY_TIME_TO_MAX
#define MOUSEKEY_TIME_TO_MAX 20

#undef MANUFACTURER
#define MANUFACTURER "Dunno"
#undef DESCRIPTION
#define DESCRIPTION "Mechanical keyboard"

#define FORCE_NKRO
// #define COMBO_COUNT 1

// https://docs.qmk.fm/#/feature_advanced_keycodes?id=ignore-mod-tap-interrupt
#define IGNORE_MOD_TAP_INTERRUPT
