#include QMK_KEYBOARD_H
#include "version.h"

enum layers { BASE, MOUS, NUMP, FUNC, SPEC, WASD };

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
[BASE] = LAYOUT_ergodox(
KC_1,	KC_2,	KC_3,	KC_4,	KC_5,	KC_6,	KC_NO,
KC_GRV,	KC_Q,	KC_W,	LT(SPEC, KC_E),	KC_R,	KC_T,	KC_NO,
KC_ESC,	LCTL_T(KC_A),	LALT_T(KC_S),	LGUI_T(KC_D),	LSFT_T(KC_F),	LT(NUMP, KC_G),
KC_LSFT,	KC_Z,	KC_X,	LT(FUNC, KC_C),	KC_V,	KC_B,	KC_NO,
KC_CAPS,	KC_NO,	KC_NO,	C(KC_K),	S(KC_Q),
					KC_APP,	KC_LGUI,
						KC_NO,
				KC_SPC,	KC_NO,	LGUI(KC_Z),

KC_NO,	KC_7,	KC_8,	KC_9,	KC_0,	KC_MINS,	KC_EQL,
KC_NO,	KC_Y,	KC_U,	LT(SPEC, KC_I),	KC_O,	KC_P,	KC_LBRC,
	KC_H,	RSFT_T(KC_J),	RGUI_T(KC_K),	LALT_T(KC_L),	RCTL_T(KC_SCLN),	KC_QUOT,
TG(WASD),	KC_N,	KC_M,	LT(MOUS, KC_COMM),	KC_DOT,	CTL_T(KC_SLSH),	KC_RSFT,
	KC_TAB,	KC_RALT,	KC_RBRC,	KC_NUHS,	KC_CAPS,
KC_NO,	KC_NO,
KC_NO,
LGUI(KC_Z),	KC_NO,	KC_ENT
),

[NUMP] = LAYOUT_ergodox(
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
KC_NO,	_______,	_______,	_______,	_______,	_______,
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
_______,	_______,	_______,	_______,	_______,
					_______,	_______,
						_______,
				_______,	_______,	_______,

_______,	KC_NO,	KC_NO,	KC_PSLS,	KC_PAST,	KC_PMNS,	KC_NO,
_______,	KC_NO,	LSFT(KC_5),	LSFT(KC_8),	LSFT(KC_4),	KC_PSLS,	KC_NO,
	KC_9,	LSFT(KC_9),	LSFT(KC_3),	LSFT(KC_0),	KC_PPLS,	_______,
_______,	KC_NO,	LSFT(KC_2),	LSFT(KC_MINS),	LSFT(KC_6),	KC_PENT,	_______,
	LSFT(KC_7),	KC_KP_DOT,	LSFT(KC_7),	KC_NO,	KC_NO,
_______,	_______,
_______,
_______,	_______,	_______
),

[FUNC] = LAYOUT_ergodox(
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
KC_NO,	_______,	_______,	_______,	_______,	_______,
KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	KC_NO,	_______,
_______,	_______,	_______,	_______,	_______,
					_______,	_______,
						_______,
				_______,	_______,	_______,

_______,	KC_F1,	KC_F2,	KC_F3,	KC_F4,	KC_F5,	LCA(KC_F1),
_______,	KC_F6,	KC_F7,	KC_F8,	KC_F9,	KC_F10,	LCA(KC_F2),
	KC_F11,	KC_F12,	KC_F13,	KC_F14,	KC_F15,	LCA(KC_F3),
_______,	KC_F16,	KC_F17,	KC_F18,	KC_F19,	KC_F20,	LCA(KC_F4),
	KC_F21,	KC_F22,	KC_F23,	KC_F24,	_______,
_______,	_______,
_______,
_______,	_______,	_______
),

[MOUS] = LAYOUT_ergodox(
_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	KC_MS_BTN1,	KC_MS_U,	KC_MS_BTN2,	_______,	_______,
_______,	KC_MS_WH_LEFT,	KC_MS_L,	KC_MS_D,	KC_MS_R,	KC_MS_WH_RIGHT,
_______,	_______,	KC_MS_BTN3,	KC_MS_WH_DOWN,	KC_MS_WH_UP,	_______,	_______,
_______,	_______,	_______,	_______,	_______,
					_______,	_______,
						_______,
				KC_MS_BTN2,	_______,	_______,

_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	KC_MS_WH_LEFT,	KC_MS_WH_UP,	KC_MS_BTN2,	_______,	_______,
	KC_MS_BTN1,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	_______,	KC_MS_WH_DOWN,	KC_MS_WH_RIGHT,	_______,	_______,
	_______,	_______,	_______,	_______,	_______,
_______,	_______,
_______,
_______,	_______,	_______
),

[SPEC] = LAYOUT_ergodox(
_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	KC_NO,	KC_NO,	KC_PSCR,	_______,	_______,
_______,	_______,	_______,	_______,	_______,	KC_INSERT,
_______,	_______,	KC_NO,	KC_DOWN,	KC_UP,	KC_DEL,	_______,
_______,	_______,	_______,	_______,	_______,
					_______,	_______,
						_______,
				KC_BSPC,	_______,	_______,

_______,	KC_MPRV,	KC_VOLD,	KC_MUTE,	KC_VOLU,	KC_MNXT,	_______,
_______,	KC_PGDN,	KC_HOME,	_______,	_______,	KC_RIGHT,	_______,
	_______,	KC_LEFT,	_______,	_______,	_______,	_______,
_______,	KC_PGUP,	KC_END,	KC_NO,	_______,	_______,	_______,
	KC_NO,	KC_NO,	KC_NO,	_______,	_______,
_______,	_______,
_______,
_______,	_______,	_______
),

[WASD] = LAYOUT_ergodox(
_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	KC_UP,	_______,	_______,	_______,	_______,
_______,	KC_LEFT,	KC_DOWN,	KC_RIGHT,	_______,	_______,
_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	_______,	_______,	_______,
					_______,	_______,
						_______,
				_______,	_______,	_______,

_______,	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	_______,	_______,	_______,	_______,	_______,
	_______,	_______,	_______,	_______,	_______,	_______,
_______,	_______,	_______,	_______,	_______,	_______,	_______,
	_______,	_______,	_______,	_______,	_______,
_______,	_______,
_______,
_______,	_______,	_______
),
};

// Runs just one time when the keyboard initializes.
void matrix_init_user(void) {
};

// Runs whenever there is a layer state change.
layer_state_t layer_state_set_user(layer_state_t state) {
	ergodox_board_led_off();
	ergodox_right_led_1_off();
	ergodox_right_led_2_off();
	ergodox_right_led_3_off();
	uint8_t layer = biton32(state);
	switch (layer) {
	case WASD:
		ergodox_right_led_3_on();
		break;
	}
	return state;
};

/* vim:set ts=16: */
