#include <alsa/asoundlib.h>
#include <fcntl.h>
#include <locale.h>
#include <math.h>
#include <stdio.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define SND_CTL_SUBSCRIBE 1

#define die(label, s) do { fputs(s "\n", stderr); goto label; } while (0)
#define snd_die(label, s) do { fprintf(stderr, s ": %s\n", snd_strerror(err)); goto label; } while (0)

int
main(void) {
	snd_ctl_event_t *event;
	snd_ctl_t *ctl;
	snd_mixer_t *mixer;
	snd_mixer_selem_id_t *sid;
	snd_mixer_elem_t *elem;
	int err;
	char const *card;
	char const *mixer_name;
	int const mixer_index = 0;

	setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	(mixer_name = getenv("BLOCK_INSTANCE")) || (mixer_name = "Master");
	card = "default";

	if ((err = snd_ctl_open(&ctl, card, SND_CTL_READONLY)) < 0)
		snd_die(err, "Failed to open card");

	if ((err = snd_ctl_subscribe_events(ctl, SND_CTL_SUBSCRIBE)) < 0)
		snd_die(err_close, "Failed to subscribe to events");

	snd_mixer_selem_id_alloca(&sid);
	snd_mixer_selem_id_set_index(sid, mixer_index);
	snd_mixer_selem_id_set_name(sid, mixer_name);

	snd_ctl_event_alloca(&event);

	for (;;) {
		wchar_t const *icon;
		long vol_100db;
		long minvol_100db, maxvol_100db;
		int unmuted;

		if ((err = snd_mixer_open(&mixer, 0 /* Unused. */)) < 0)
			snd_die(err_close, "Failed to open mixer");

		if ((err = snd_mixer_attach(mixer, card)) < 0)
			snd_die(err_free_mixer, "snd_mixer_attach()");

		if ((err = snd_mixer_selem_register(mixer, NULL, NULL)) < 0)
			snd_die(err_free_mixer, "snd_mixer_selem_register()");

		if ((err = snd_mixer_load(mixer)) < 0)
			snd_die(err_free_mixer, "snd_mixer_load()");

		if ((elem = snd_mixer_find_selem(mixer, sid)) == NULL)
			die(err_free_mixer, "snd_mixer_find_selem(): Not found");

		if ((err = snd_mixer_selem_get_playback_dB_range(elem, &minvol_100db, &maxvol_100db)) < 0)
			snd_die(err_free_mixer, "snd_mixer_selem_get_playback_dB_range()");

		if ((err = snd_mixer_selem_get_playback_dB(elem, SND_MIXER_SCHN_MONO, &vol_100db)) < 0)
			snd_die(err_free_mixer, "snd_mixer_selem_get_playback_dB()");

		if (snd_mixer_selem_has_playback_switch(elem)) {
			if ((err = snd_mixer_selem_get_playback_switch(elem, SND_MIXER_SCHN_MONO, &unmuted)) < 0)
				snd_die(err_free_mixer, "snd_mixer_selem_get_playback_switch()");
		} else {
			unmuted = 1;
		}

		if ((err = snd_mixer_close(mixer)) < 0)
			snd_die(err_close, "snd_mixer_close()");

		icon = unmuted ? L"墳" : L"婢"; /* "奄" "奔" */
		printf("%ls %.2fdB\n",
				icon,
				vol_100db != minvol_100db
					? vol_100db / 100.0
					: -INFINITY);

		for (;;) {
			if ((err = snd_ctl_read(ctl, event)) < 0)
				snd_die(err_close, "Failed to read event");

			/* Changed. */
			if (snd_ctl_event_get_type(event) == SND_CTL_EVENT_ELEM
			    && (snd_ctl_event_elem_get_mask(event) & SND_CTL_EVENT_MASK_VALUE))
				break;
		}
	}

err_free_mixer:
	(void)snd_mixer_close(mixer);
err_close:
	(void)snd_ctl_close(ctl);
err:
	return (err == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
}
