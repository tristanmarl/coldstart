# Device and simulator evidence

Simulator checks are not hardware acceptance; marks are upgraded only from recorded device results.

## Simulator (0.1.1)

- [x] Unit tests: `PASSED (passed=11, failed=0, errors=0)` in the fr965 simulator (`scripts/test.sh`).
- [x] Build: `fr965` and `fr255s` compile without errors or warnings; all 53 manifest products compile.
- [x] Layout screenshots of Home, Shower and Summary on fr965 (`docs/screenshots/`, taken with fixed debug data in a temporary build; the fr255s shots from 0.1.0 were removed as stale): content balanced top to bottom, nothing clipped, button hints at the edge.
- [x] Strict typecheck `monkeyc -l 3` builds clean for fr965 and fr255s.
- [ ] Not exercised in the simulator: real HR, beat intervals, vibration, saving a FIT activity, keys.

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
