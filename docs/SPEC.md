# ColdStart — spec

ColdStart is a Monkey C Connect IQ watch app that times cold showers and saves each one as a Garmin activity. Reference project for toolchain, structure and conventions: `~/Projects/NextSet` (read its `CLAUDE.md`, `AGENTS.md`, `docs/TOOLCHAIN.md`, `scripts/test.sh`, `.github/`). Do not modify NextSet.

## Decisions (from the user)

| Topic | Decision |
| --- | --- |
| Timer | Target countdown. Before start, Home shows the target; during the shower it counts down, then counts overtime. Stop any time. |
| Target | Remember the last target (default 2:00). On Home UP/DOWN change it in 15 s steps (range 0:15–15:00), START begins. Persist the choice. |
| Vibration | Short pulse every 30 s; a long/strong pattern when the target is reached. Guard with `Attention has :vibrate`. |
| FIT activity | `ActivityRecording.createSession` with `:sport => Activity.SPORT_MEDITATION`, `:subSport => Activity.SUB_SPORT_BREATHING`, `:name => "Cold Shower"`. If a device lacks these constants (check with `has`), fall back to `SPORT_GENERIC` / `SUB_SPORT_GENERIC`. |
| Data | Duration, heart rate (comes with ActivityRecording), cold-shock response and HRV (see "Cold-shock response and HRV" below). No stress or breathing metrics (no live reading available during an activity). No post-shower questions. FIT session field `target_s` (uint16) via FitContributor; all FitContributor failures must be swallowed. |
| On-watch stats | Streak counter (consecutive local calendar days with ≥1 saved shower; today without a shower yet does not break a streak that ran through yesterday) and the last saved shower's duration ("Last 2:15"). No best streak, no totals (no counts or minutes per week/month/all-time). Stored in `Application.Storage`. |
| Devices | Same 53 five-button CIQ 5+ products as NextSet `manifest.xml`, `minSdkVersion="5.0.0"`, reference device `fr965`. Guard APIs some targets lack with `has` (MIP watches like fr255 have no `Graphics.getVectorFont`). |
| Repo | Git in `~/coldstart`, GitHub repo `tristanmarl/coldstart` (public), CI compile check (fr965 + fr255s) and a tag-driven release workflow modeled on NextSet. |
| Signing | New key `~/.garmin-keys/ColdStartDeveloperKey.pem` / `.der` (RSA 4096, DER = PKCS#8). Never commit it. CI secret name `COLDSTART_DEV_KEY` (the user adds it; don't try to set secrets). |

## Cold-shock response and HRV

**Cold-shock response** (derived from heart rate, no extra sensors):
- `hr_rest`: baseline HR before START. Read `Activity.getActivityInfo().currentHeartRate` (or `Sensor.Info.heartRate`) on Home and keep a rolling median of the last ~10 s of valid samples; at START freeze it. If none is available, it stays null and the other two shock values are skipped.
- `hr_peak`: max HR in the first 60 s of the shower.
- `calm_s`: seconds from START until HR first stays within `hr_rest + 10` bpm for 10 consecutive seconds after the peak; null if it never happens before STOP.
- Sample HR once per second in the existing 1 s timer (cheap reads only).

**HRV (RMSSD)** from live beat-to-beat intervals:
- `Sensor.registerSensorDataListener(method(:onSensorData), {:period => 1, :heartBeatIntervals => {:enabled => true}})`, guarded with `Sensor has :registerSensorDataListener`; the callback must be public. Unregister on stop/discard/app stop.
- Filter intervals: keep 300–2000 ms and drop any that differ >20 % from the previous accepted interval (artifact rejection). RMSSD = sqrt(mean of squared successive differences) over accepted intervals.
- Keep running sums only (no growing arrays): whole-shower RMSSD plus one RMSSD per 30 s window. A window with <10 accepted intervals is invalid.
- Optical HRV on the wrist in a shower is noisy: label it "HRV (est.)" and show nothing when invalid.

**FIT:** session fields `hr_rest`, `hr_peak` (uint8), `calm_s` (uint16), `hrv_rmssd` (uint16, ms); record field `hrv_30s` (uint16, written once per closed 30 s window, invalid otherwise). Invalid value when null. Add entries to `resources/fitcontributions/fitcontributions.xml` and strings like NextSet.

**UI:** Home shows the live baseline HR small. Summary shows rest → peak HR, time to calm and HRV (est.); hide null rows. The shower screen stays as specced (no HRV live).

**Tests:** pure-logic tests for baseline median, peak window, calm detection (incl. never calm), interval filtering, RMSSD values on known inputs, 30 s window validity, null→FIT invalid mapping.

## Screens and flow (button-only, five-button watches)

**Touch is disabled everywhere in the app** (wet fingers/water on the screen must never start, stop, save or discard anything). Every view's delegate is a `WatchUi.BehaviorDelegate` (or `InputDelegate`) that overrides `onTap`, `onSwipe`, `onFlick`, `onDrag`, `onHold` and `onRelease` and returns `true` without doing anything, so the firmware does not map them to behaviours such as `onSelect`/`onBack`/`onNextPage`. Actions are bound to physical keys only: check `KeyEvent` keys in `onKey` (or behaviours that only fire from keys) and, where a behaviour can come from either, make sure the touch path is already consumed. Do not use `Menu2`/`Confirmation`/pickers anywhere in the shower → summary flow (they accept taps); build the save/discard choice as a custom key-only view. The app has no menus at all. Add a test-free note to `docs/DEVICE_TESTS.md`: "Touch ignored during shower" is a physical-watch check (FR965 has a touchscreen).


**Button hints:** no arrows or icons stacked above/below the time. Draw small markers at the screen edge next to the physical button they belong to, using NextSet's approach (`~/Projects/NextSet/source/ui/Icons.mc`, `edge()`): angles measured on the fr965 simulator layout, `ANGLE_UP = 180`, `ANGLE_DOWN = 210`, `ANGLE_START = 25`, `ANGLE_BACK = 335`, kept as constants in one place. On Home: a "+" / up chevron at UP, "−" / down chevron at DOWN, a play marker at START. During the shower: a stop marker at START only. Summary: check at START (save), cross at BACK (discard). Keep the time centred and uncluttered.

**Layout:** use the whole round face, not the top half. Lay out every screen on a vertical grid relative to `dc.getHeight()`, centred on the screen middle: the main number (target / countdown / duration) is the largest element, sits at exactly 50 % height and uses the biggest number font that fits (`FONT_NUMBER_THAI_HOT` or `FONT_NUMBER_HOT`, vector font if `Graphics has :getVectorFont`, with a fallback for MIP watches). One secondary line above it (~28 %) and one or two below it (~70 % and ~80 %); nothing else. Keep text out of the outer ~12 % ring where the round bezel clips and where the button hints sit. Draw text with vertical centring (`TEXT_JUSTIFY_VCENTER`) so font height doesn't shift rows. On the shower screen a progress arc around the edge (thick, inside the hint ring) shows progress to the target. Verify by screenshots of Home, Shower and Summary on fr965 (454 px AMOLED) and fr255s (218 px MIP): content must be visually balanced top-to-bottom and nothing clipped.

1. **Home**: app name, streak ("🔥"-free: draw a simple icon or text "Streak 5 d"), target time large, "Last m:ss" (last saved shower duration, hidden before the first one). UP/DOWN adjust target, START starts, BACK exits. No menu.
2. **Shower** (active): big remaining time counting down, then "+0:12" overtime in a different colour after target; current HR below; a progress ring/arc toward the target. START stops (pause not needed). BACK does nothing or asks to stop — never exits silently while recording. Ignore a second START within 800 ms (debounce like NextSet).
3. **Summary**: duration, target hit yes/no, avg/max HR if available. START = Save (saves FIT, updates stats), BACK/menu = Discard with confirmation. Very short showers (<10 s) default to discard with a prompt.
4. No separate Stats screen: Home shows the current streak and the last shower's duration directly. Hold UP/MENU on Home does nothing (or remove that binding).

Keep the screen on during the shower if supported (`Attention.backlight` / `WatchUi` settings as appropriate). Handle app stop during recording: save the session as is (don't lose it), and update stats.

## Code layout (mirror NextSet's style)

- `manifest.xml` (new app id — generate a fresh UUID, no dashes), `monkey.jungle`, `tests.jungle`, `resources/` (strings, launcher icon drawable — draw a simple snowflake/droplet PNG, sizes per NextSet's launcher), `source/`, `source/ui/`, `tests/`.
- Separate pure logic (streak calculation, target clamping, countdown formatting, vibration schedule) from UI so it is unit-testable with `(:test)` functions taking `Test.Logger`.
- Recorder class wrapping ActivityRecording, swallowing FitContributor errors (see NextSet `StrengthRecorder.mc`).
- Timer callbacks passed to `method(:x)` must be public (NextSet crashed on device with a private one).
- No storage writes in the same tick as vibration; keep that tick light.
- Permissions: `Fit`, `FitContributor`, `Sensor` if needed for HR display. No `Communications`.

## Build and test

SDK 9.2.0 at `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2`; every `monkeyc` call needs `-y ~/.garmin-keys/ColdStartDeveloperKey.der`. Provide `scripts/test.sh` adapted from NextSet (judge by the PASSED summary line, not exit code). Build must succeed for `fr965` and `fr255s`; unit tests must pass in the simulator.

## Docs to write

`README.md` (what it is, install by sideload, usage, limitations), `CLAUDE.md` + `AGENTS.md` (commands, architecture, rules, key handling), `docs/DEVICE_TESTS.md` (simulator results recorded; physical-watch checks listed as pending — a simulator result is not a device result), `LICENSE` (MIT, Tristan Marl, like NextSet), `.gitignore` (`bin/`, keys, `.DS_Store`).
