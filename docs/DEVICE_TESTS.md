# Device and simulator evidence

Simulator checks are not hardware acceptance; marks are upgraded only from recorded device results.

## Simulator (0.1.1)

- [x] Unit tests: `PASSED (passed=13, failed=0, errors=0)` in the fr965 simulator (`scripts/test.sh`).
- [x] Build: `fr965` and `fr255s` compile without errors or warnings; all 53 manifest products compile.
- [x] Layout screenshots of Home, Shower and Summary on fr965 and fr255s (`docs/screenshots/`, taken with fixed debug data in a temporary build): content balanced top to bottom, nothing clipped, button hints at the edge.
- [x] Strict typecheck `monkeyc -l 3` builds clean for fr965 and fr255s.
- [ ] Not exercised in the simulator: real HR, beat intervals, vibration, saving a FIT activity, keys.

## Pending physical-watch checks (FR965)

- [ ] **PENDING** (0.1.1) Crash recovery: kill the app (or pull the battery path via a forced restart) during a shower of 30 s or more; on the next launch Home shows "Recovered m:ss", the streak day and "Last" are credited from the checkpoint, and no FIT activity exists for it. A kill within the first 10 s credits nothing.
- [ ] **PENDING** (0.1.1) Elapsed time survives a phone/clock sync mid-shower without jumping; no checkpoint write lands in a vibrating second (no crash at 30 s pulses or at the target).

- [ ] **PENDING** Touch ignored during the shower: tapping, swiping, long-pressing and wiping the screen with a wet finger on Home, Shower, Summary and the discard choice never starts, stops, saves, discards or changes the target.
- [ ] **PENDING** Keys: UP/DOWN change the target in 15 s steps and it is remembered after relaunch; START begins, START stops; a second START within 800 ms is ignored; BACK is ignored during the shower and exits on Home.
- [ ] **PENDING** Countdown reaches 0:00, then shows orange `+m:ss`; 30 s pulses; long vibration at the target (also with targets not on the 30 s grid).
- [ ] **PENDING** Saved activity appears in Garmin Connect as Meditation / Breathing with duration and heart rate; fallback to Generic if the sport is rejected.
- [ ] **PENDING** FIT fields: `target_s`, `hr_rest`, `hr_peak`, `calm_s`, `hrv_rmssd` and record field `hrv_30s` present, invalid values for unmeasured ones; Connect displays the session fields.
- [ ] **PENDING** Resting HR on Home: baseline appears after a few seconds (Activity or Sensor reading outside an activity) and is frozen at START.
- [ ] **PENDING** HRV: `Sensor.registerSensorDataListener` delivers beat intervals in the shower; RMSSD is plausible or hidden when invalid.
- [ ] **PENDING** Streak across midnight and "Last m:ss" after saving; today without a shower keeps yesterday's streak.
- [ ] **PENDING** Summary: showers under 10 s offer discard by default; BACK asks before discarding; stopping the app mid-shower saves the activity.
- [ ] **PENDING** Backlight stays on during the shower; no crash or watchdog at the vibration tick (no storage writes there).
- [ ] **PENDING** Layout on other watches (small MIP screens beyond fr255s) and button hint positions on watches other than fr965.
