# ColdStart

ColdStart is a Garmin Connect IQ watch app that times cold showers and saves each one as a Garmin activity (Meditation / Breathing, falling back to Generic). It targets 53 five-button Connect IQ 5+ watches (see `manifest.xml`), developed against the Forerunner 965 simulator. Touch is ignored everywhere, so water on the screen cannot start, stop, save or discard anything.

![Home](docs/screenshots/fr965-home.png) ![Shower](docs/screenshots/fr965-shower.png) ![Summary](docs/screenshots/fr965-summary.png)

## Usage

- **Home:** target time in the middle (default 2:00), the current streak above, the last saved shower below. UP/DOWN change the target in 15 s steps (0:15 to 15:00, remembered), START begins, BACK exits.
- **Shower:** the time counts down to the target, then counts overtime as `+m:ss` in orange. A ring shows progress, with the current heart rate below. The watch pulses every 30 s and vibrates long when the target is reached. START stops; BACK is ignored while a shower runs. The backlight is kept on where supported.
- **Summary:** duration, target hit or missed, average and maximum heart rate, and the cold-shock and HRV values below. START saves the activity, BACK (or MENU) asks to discard. Showers shorter than 10 s default to discard. If the app is stopped mid-shower the session is saved as it is (discarded when under 10 s).

Cold-shock response (from heart rate): resting HR (median of the last ~10 s on Home, frozen at START), peak HR in the first 60 s, and time to calm (HR within resting + 10 bpm for 10 s). HRV is RMSSD from beat-to-beat intervals with artifact filtering, shown as "HRV (est.)". The FIT activity carries session fields `target_s`, `hr_rest`, `hr_peak`, `calm_s`, `hrv_rmssd` and a record field `hrv_30s` (one value per closed 30 s window). Values that were not measured are written as the FIT invalid value.

The streak counts consecutive local calendar days with at least one saved shower; a day without a shower yet does not break a streak that ran through yesterday. Only the streak and the last duration are stored, in `Application.Storage`.

## Install (sideload)

Build a `.prg` (see CLAUDE.md) or take one from a release, connect the watch over USB and copy it to `GARMIN/APPS/` on the watch. A build is signed with the developer key, so updating an installed copy needs a build signed with the same key.

## Limitations

- Heart-rate based values need an optical HR reading; without a resting baseline the cold-shock values are skipped.
- Wrist optical HRV in a shower is noisy and may be empty; treat it as an estimate.
- Only simulator results exist so far; physical-watch checks are listed in `docs/DEVICE_TESTS.md`.
- Layouts were checked on fr965 and fr255s only.
- No phone sync or settings: no `Communications` permission.

## License

MIT, see `LICENSE`.
