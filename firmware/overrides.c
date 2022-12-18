#include "keyboard.h"

/* Key -> gamepad mapping.  We override this to swap buttons A and B for NES. */

unsigned char joy_keymap[]=
{
	KEY_2,
	KEY_6,
	KEY_ALT,
	KEY_LCTRL,
	KEY_W,
	KEY_S,
	KEY_A,
	KEY_D,
	KEY_1,
	KEY_5,
	KEY_ALTGR,
	KEY_RCTRL,
	KEY_UPARROW,
	KEY_DOWNARROW,
	KEY_LEFTARROW,
	KEY_RIGHTARROW,
};

