# ColdStart

<img src="docs/store/icon-500.png" width="96" align="right" alt="ColdStart icon">

ColdStart is a Garmin Connect IQ watch app that times cold showers and saves each one as a Garmin activity (Meditation / Breathing, falling back to Generic). It targets 53 five-button Connect IQ 5+ watches (see `manifest.xml`), developed against the Forerunner 965 simulator. Touch is ignored everywhere, so water on the screen cannot start, stop, save or discard anything.

![Home](docs/screenshots/fr965-home.png) ![Shower](docs/screenshots/fr965-shower.png) ![Summary](docs/screenshots/fr965-summary.png)

**Store text:** Time your cold showers. Set a target, count down (then overtime), feel a pulse every 30 s and a long buzz at the target, and save each shower as a Garmin activity with heart rate. Keeps a day streak and your last time. Button-only: touch is ignored, so wet fingers and water can not trigger anything.

## Usage

- **Home:** target time in the middle (default 2:00), the current streak above, the last saved shower below. UP/DOWN change the target in 15 s steps (0:15 to 15:00, remembered), START begins, BACK exits.
- **Shower:** the time counts down to the target, then counts overtime as `+m:ss` in orange. A ring shows progress, with the current heart rate below. The watch pulses every 30 s (300 ms), and at the target vibrates for 1 s, sounds a tone where the watch has a beeper, and repeats the 1 s vibration 2 s later; the screen turns green and shows "Target!" for 5 s. Garmin's "Do Not Disturb" can suppress app vibrations and tones, so turn it off for showers. START stops; BACK is ignored while a shower runs. The backlight is kept on where supported.
- **Summary:** duration, target hit or missed, average and maximum heart rate, and heart rate as three columns (MIN, AVG, MAX in bpm) below. START saves the activity, BACK (or MENU) asks to discard. Showers shorter than 10 s default to discard. If the app is stopped mid-shower the session is saved as it is (discarded when under 10 s).

The activity is saved with duration and heart rate (Garmin Connect shows min, max and average HR natively) plus one custom session field, `target_s`. The Summary shows MIN, AVG and MAX heart rate in three labelled columns and hides them when no heart rate was measured.

The streak counts consecutive local calendar days with at least one saved shower; a day without a shower yet does not break a streak that ran through yesterday. Only the streak and the last duration are stored, in `Application.Storage`.

## Install (sideload)

Build a `.prg` (see CLAUDE.md) or take one from a release, connect the watch over USB and copy it to `GARMIN/APPS/` on the watch. A build is signed with the developer key, so updating an installed copy needs a build signed with the same key.

## Limitations

- Heart-rate values need an optical HR reading and may be empty or noisy in water.
- Only simulator results exist so far; physical-watch checks are listed in `docs/DEVICE_TESTS.md`.
- Layouts were checked on fr965 and fr255s only.
- If the app crashes or is killed mid-shower the FIT activity is lost (it cannot be recovered). The streak day and last duration are credited from a checkpoint written every 30 s on the next launch (shown as "Recovered m:ss"), if the shower lasted at least 10 s.
- No phone sync or settings: no `Communications` permission.

## License

MIT, see `LICENSE`.
