# Device and simulator evidence

Simulator checks are not hardware acceptance; marks are upgraded only from recorded device results.

## Simulator (0.1.1)

- [x] Unit tests: `PASSED (passed=11, failed=0, errors=0)` in the fr965 simulator (`scripts/test.sh`).
- [x] Build: `fr965` and `fr255s` compile without errors or warnings; all 53 manifest products compile.
- [x] Layout screenshots of Home, Shower and Summary on fr965 (`docs/screenshots/`, taken with fixed debug data in a temporary build; the fr255s shots from 0.1.0 were removed as stale): content balanced top to bottom, nothing clipped, button hints at the edge.
- [x] Strict typecheck `monkeyc -l 3` builds clean for fr965 and fr255s.
- [ ] Not exercised in the simulator: real HR, beat intervals, vibration, saving a FIT activity, keys.

## Touch bug in 0.1.1 (user report, physical FR965)

0.1.1 consumed `onTap`, `onSwipe`, `onFlick`, `onDrag`, `onHold` and `onRelease`, but on the user's FR965 touch still triggered actions (unusable in the shower): the firmware evidently delivers behaviours (`onSelect`, `onBack`, `onNextPage`, ...) from touch without going through those callbacks. The first 0.1.2 attempt (commit 7c1505f: behaviour callbacks as no-ops on a `BehaviorDelegate`, actions in `onKey`) broke the physical buttons in the simulator, because on a `BehaviorDelegate` the buttons arrive only as behaviours. The fix makes `KeyDelegate` an `InputDelegate`, where taps reach only `onTap` and the buttons reach `onKey`. The simulator reproduces the 0.1.1 bug (a mouse click on Home starts a shower) and shows the fixed 0.1.2 ignoring clicks and drags on Home and Shower while the drawn buttons work: UP changes the target, START starts, a tap and a swipe during the shower do nothing, START stops, BACK opens the discard prompt, BACK closes it, START saves (Home shows "Saved" and the last duration), BACK on Home exits the app (checked 2026-10-30 with injected mouse events on the fr965 simulator). This is not a device result.

- [ ] **PENDING** (0.1.2, FR965) Touch really ignored on the watch: tap, long-press and swipe on Home, Shower, Summary and the discard choice do nothing; the five physical keys still work as listed below (START, BACK, UP, DOWN, hold UP does nothing). LIGHT keeps its firmware behaviour.
- [ ] **PENDING** (0.1.2) Physical keys reach `onKey` with one action per press (no double action from press/release), including BACK on Home exiting the app. Verified only in the simulator by clicking the drawn buttons.

## Target vibration (user report, physical FR965)

- [x] **FAILED** (0.1.2, user report) No vibration was felt when the target was reached. The schedule logic was unit-tested but the target alert used a multi-profile pattern (3 pulses with pauses) and the 30 s pulses 60 % strength. Details (2026-10-31): a 15 s target, Do Not Disturb and sleep mode off; nothing at the target, and the shower was too short to reach a 30 s pulse, so no vibration of any kind was observed. Working theory: the pattern's 0 % pause profiles made `Attention.vibrate` throw, and the `try/catch` swallowed it (0.1.3 uses single profiles only).
- [ ] **PENDING** (0.1.3) Target alert: 1 s full-strength vibration, repeat 2 s later with a tone on watches with a beeper (tone moved off the first vibration in 0.1.3), green "Target!" screen for 5 s; 30 s pulses (300 ms, full strength) are felt in the shower; also with the target off the 30 s grid (e.g. 2:15). Check with Do Not Disturb on and off (DND can suppress app vibrations).
- [ ] **PENDING** (0.1.3) Summary heart-rate columns (MIN / AVG / MAX, "HR bpm") are readable and clear of the START/BACK markers on the FR965; simulator screenshots on fr965 and fr255s are in `docs/screenshots/`.

## Pending physical-watch checks (FR965)

- [ ] **PENDING** (0.1.1) Crash recovery: kill the app (or pull the battery path via a forced restart) during a shower of 30 s or more; on the next launch Home shows "Recovered m:ss", the streak day and "Last" are credited from the checkpoint, and no FIT activity exists for it. A kill within the first 10 s credits nothing.
- [ ] **PENDING** (0.1.1) Elapsed time survives a phone/clock sync mid-shower without jumping; no checkpoint write lands in a vibrating second (no crash at 30 s pulses or at the target).

- [ ] **PENDING** Touch ignored during the shower: tapping, swiping, long-pressing and wiping the screen with a wet finger on Home, Shower, Summary and the discard choice never starts, stops, saves, discards or changes the target.
- [ ] **PENDING** Keys: UP/DOWN change the target in 15 s steps and it is remembered after relaunch; START begins, START stops; a second START within 800 ms is ignored; BACK is ignored during the shower and exits on Home.
- [ ] **PENDING** Countdown reaches 0:00, then shows orange `+m:ss`; 30 s pulses; long vibration at the target (also with targets not on the 30 s grid).
- [ ] **PENDING** Saved activity appears in Garmin Connect as Meditation / Breathing with duration and heart rate; fallback to Generic if the sport is rejected.
- [ ] **PENDING** FIT field `target_s` is present and Connect shows min/max/avg heart rate natively.
- [ ] **PENDING** Summary "HR min · avg · max" matches Garmin Connect for the saved activity; it is hidden when no HR was measured; `Sensor.getInfo()` fallback delivers HR if `Activity.getActivityInfo()` does not.
- [ ] **PENDING** Launcher icon is readable on a 65 px device (fr965) and on a 40 px device (fr255s, per-device 40 px variant).
- [ ] **PENDING** Streak across midnight and "Last m:ss" after saving; today without a shower keeps yesterday's streak.
- [ ] **PENDING** Summary: showers under 10 s offer discard by default; BACK asks before discarding; stopping the app mid-shower saves the activity.
- [ ] **PENDING** Backlight stays on during the shower; no crash or watchdog at the vibration tick (no storage writes there).
- [ ] **PENDING** Layout on other watches (small MIP screens beyond fr255s) and button hint positions on watches other than fr965.
