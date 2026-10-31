# CLAUDE.md

ColdStart is a Monkey C Connect IQ watch app for five-button Garmin watches on Connect IQ 5+ (53 products in `manifest.xml`, minimum API 5.0.0), reference device `fr965`. Toolchain and conventions follow NextSet. Guard APIs some targets lack with `has` (MIP watches such as fr255 have no `Graphics.getVectorFont`). `AGENTS.md` has the repository rules; the original decisions are in `docs/SPEC.md`.

## Commands

SDK 9.2.0 with its `bin` on `PATH`. Every `monkeyc` call needs `-y`.

```sh
KEY="$HOME/.garmin-keys/ColdStartDeveloperKey.der"
mkdir -p bin
monkeyc -f monkey.jungle -d fr965 -o bin/ColdStart.prg -y "$KEY"
monkeyc -f monkey.jungle -d fr255s -o bin/ColdStart-fr255s.prg -y "$KEY"
monkeydo bin/ColdStart.prg fr965
monkeyc -l 3 -f monkey.jungle -d fr965 -o bin/ColdStart.prg -y "$KEY"   # strict typecheck, must be clean
monkeyc --unit-test -f tests.jungle -d fr965 -o bin/ColdStart-tests.prg -y "$KEY"
monkeydo bin/ColdStart-tests.prg fr965 -t     # without -t it hangs
scripts/test.sh                                # build + run; exit 0 only on "PASSED (passed=N, failed=0, errors=0)"
```

`monkeydo` may exit 1 after a passing run; read the summary line. A stale simulator can hang it (`scripts/test.sh` restarts it).

## Architecture

- `source/ColdLogic.mc`: pure logic (target clamp/step, countdown text, breathing cue `breathCue` (whole session, 4 s in / 6 s out, visual only), vibration schedule, local day index, streak and last-duration stats, crash-recovery credit, HR line). `HrTracker` (in `ColdLogic.mc`) keeps min/max/avg of valid heart-rate samples (30-250 bpm). Unit-tested in `tests/`.
- `source/ColdStore.mc`: `Application.Storage` access (target, stats), always guarded; local UTC offset from the calendar fields.
- `source/ShowerRecorder.mc`: wraps `ActivityRecording` (Meditation/Breathing, fallback Generic) and the single FitContributor field `target_s`; every FitContributor failure is swallowed.
- `source/ColdStartApp.mc`: shower state machine (idle, running, review), 1 s timer, vibration, HR sampling, 800 ms START debounce, save/discard, stop-handling (saves an open shower).
- `source/ui/`: views and delegates. Every delegate extends `KeyDelegate`, which consumes all touch callbacks. No `Menu2`, confirmation or picker is used (they accept taps); the discard choice is the key-only `ConfirmView`. `Icons.mc` draws button hints at the edge (angles from the fr965 layout, one place). `Draw.mc` has text helpers and the big-number font choice.

## Session type and hold UP

Two session types (`ColdLogic.TYPE_SHOWER` / `TYPE_PLUNGE`, storage key `type`, validated by `ColdLogic.validType`, default Cold Shower). `ColdLogic.typeName` is the Garmin activity name, passed to `ShowerRecorder.start` and fixed for the session. Hold UP on Home (`HomeDelegate.onMenuKey`) toggles it. How a hold arrives: `KeyDelegate.onKeyPressed` records the UP press time; a hold is either `KEY_MENU` (what the five-button firmware is expected to send) or, as in the simulator, a `KEY_UP` action whose press lasted `ColdLogic.LONG_PRESS_MS` (700 ms). Both call `onMenuKey` once, a `KEY_UP` release within 1.5 s of a `KEY_MENU` is swallowed, and a short UP acts on release only (the simulator reports the action at release). Shower, Summary and Confirm leave `onMenuKey` as a no-op.

## Icon

`resources/icon/coldstart.svg` is the source. Render with `qlmanage -t -s 500 -o <dir> resources/icon/coldstart.svg` and `sips -z 65 65` / `sips -z 40 40`: `resources/drawables/launcher.png` (65 px), `resources-launcher40/drawables/launcher.png` (40 px, used by the 40 px launcher devices through per-product `resourcePath` lines in `monkey.jungle`), `docs/store/icon-500.png` (store). The `Sensor` permission is kept only for the `Sensor.getInfo()` heart-rate fallback.

## Rules

- Timer callbacks passed to `method(:x)` must be public.
- No storage writes and no backlight call in a vibrating tick; `onTick` stays light (HR reads only). Vibrations are single-profile (`VibeProfile(100, 1000)` at the target and again 2 s later via `_alertRepeatAt` from a later tick, `VibeProfile(100, 300)` for the 30 s pulses) plus `Attention.playTone` with the repeat (not the first target vibration, so a tone cannot cut it short), all through `ColdLogic.alertStep` (pure, unit-tested). Do not use multi-profile patterns: the FR965 did not vibrate for them (0.1.2).
- Pause: START in a running session pauses (`pauseShower`: stops the 1 s timer, `ShowerRecorder.stop()` keeps the session open, `_alertRepeatAt` cleared, state `STATE_PAUSED`); on `PausedView` START resumes (`resumeShower`: `session.start()`, new `_runStartMs`) and BACK finishes (`finishShower` -> Summary). Active time = `_activeMs` (finished runs) + the current run, via `ColdLogic.activeMs`/`activeSec` from `System.getTimer()` deltas; `elapsed`, the alerts, pulses and the crash checkpoint all use active time, so paused time never counts and a reached target never fires again. `onStop` while paused saves/discards like a finished session. A short `VibeProfile(100, 200)` confirms pause/resume (sent from the key handler, never in a tick).
- Elapsed time is measured with `System.getTimer()` deltas (`ColdLogic.elapsedSec`), never `Time.now()` differences, so a clock sync cannot make it jump; `Time.now()` is only used for the start timestamp and day index.
- Crash recovery: `startShower` writes the storage key `open` = `[startedAtUtc, dayIndex, target, elapsedSec]`; `onTick` refreshes it when `elapsed % 30 == 15` (never in a vibrating second); save/discard clear it. `onStart` credits a leftover `open` (streak day + last duration) via `ColdLogic.openCredit` if it was at least 10 s and shows "Recovered m:ss". The FIT activity is not recoverable.
- `monkeyc -l 3` (strict typecheck) must build clean for fr965 and fr255s.
- Every delegate extends `KeyDelegate`, which is a `WatchUi.InputDelegate` (not a `BehaviorDelegate`). On a BehaviorDelegate the firmware turns taps into `onSelect` and the buttons into behaviours (`onPreviousPage`, ...) that never reach `onKey`, so behaviours cannot be used (0.1.1 let touch act on a real FR965; the first 0.1.2 attempt with no-op behaviours broke the buttons). Actions live only in the `onXxxKey` methods (`onStartKey`, `onBackKey`, `onUpKey`, `onDownKey`, `onMenuKey`), dispatched from `KeyDelegate.onKey` for real key presses (`PRESS_TYPE_DOWN`/`UP` edges are ignored); all touch callbacks are consumed no-ops. Home BACK exits by `popView` of the root view.
- Keep long `&&` chains in tests split into named variables (compiler OOM otherwise).
- Never commit or print signing keys. Signing key: `~/.garmin-keys/ColdStartDeveloperKey.der` (PEM beside it, mode 600). Reuse it for updates and keep a backup. CI secret `COLDSTART_DEV_KEY` is the base64 of the DER file. Device files come from this repo's draft `ci-devices` release (`ciq-devices.zip`, copied from NextSet), read with the workflow token.
- Simulator results are not device results; record them separately in `docs/DEVICE_TESTS.md`.
