#pragma once

// #define USB_POLLING_INTERVAL_MS 7

#define IGNORE_MOD_TAP_INTERRUPT

#undef MOUSEKEY_MAX_SPEED
#define MOUSEKEY_MAX_SPEED 4

#undef MOUSEKEY_WHEEL_INTERVAL
#define MOUSEKEY_WHEEL_INTERVAL 50

#undef MOUSEKEY_TIME_TO_MAX
#define MOUSEKEY_TIME_TO_MAX 20

/* #undef DEBOUNCE
#define DEBOUNCE 12 */

#undef MANUFACTURER
#define MANUFACTURER Dunno
#undef DESCRIPTION
#define DESCRIPTION Mechanical keyboard

#define FORCE_NKRO
// #define COMBO_COUNT 1

// https://docs.qmk.fm/#/feature_advanced_keycodes?id=ignore-mod-tap-interrupt
#define IGNORE_MOD_TAP_INTERRUPT
