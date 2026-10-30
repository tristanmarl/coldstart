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

- `source/ColdLogic.mc`: pure logic (target clamp/step, countdown text, vibration schedule, local day index, streak and last-duration stats, crash-recovery credit, HR line). `HrTracker` (in `ColdLogic.mc`) keeps min/max/avg of valid heart-rate samples (30-250 bpm). Unit-tested in `tests/`.
- `source/ColdStore.mc`: `Application.Storage` access (target, stats), always guarded; local UTC offset from the calendar fields.
- `source/ShowerRecorder.mc`: wraps `ActivityRecording` (Meditation/Breathing, fallback Generic) and the single FitContributor field `target_s`; every FitContributor failure is swallowed.
- `source/ColdStartApp.mc`: shower state machine (idle, running, review), 1 s timer, vibration, HR sampling, 800 ms START debounce, save/discard, stop-handling (saves an open shower).
- `source/ui/`: views and delegates. Every delegate extends `KeyDelegate`, which consumes all touch callbacks. No `Menu2`, confirmation or picker is used (they accept taps); the discard choice is the key-only `ConfirmView`. `Icons.mc` draws button hints at the edge (angles from the fr965 layout, one place). `Draw.mc` has text helpers and the big-number font choice.

## Icon

`resources/icon/coldstart.svg` is the source. Render with `qlmanage -t -s 500 -o <dir> resources/icon/coldstart.svg` and `sips -z 65 65` / `sips -z 40 40`: `resources/drawables/launcher.png` (65 px), `resources-launcher40/drawables/launcher.png` (40 px, used by the 40 px launcher devices through per-product `resourcePath` lines in `monkey.jungle`), `docs/store/icon-500.png` (store). The `Sensor` permission is kept only for the `Sensor.getInfo()` heart-rate fallback.

## Rules

- Timer callbacks passed to `method(:x)` must be public.
- No storage writes in the vibration tick; `onTick` stays light (HR reads only).
- Elapsed time is measured with `System.getTimer()` deltas (`ColdLogic.elapsedSec`), never `Time.now()` differences, so a clock sync cannot make it jump; `Time.now()` is only used for the start timestamp and day index.
- Crash recovery: `startShower` writes the storage key `open` = `[startedAtUtc, dayIndex, target, elapsedSec]`; `onTick` refreshes it when `elapsed % 30 == 15` (never in a vibrating second); save/discard clear it. `onStart` credits a leftover `open` (streak day + last duration) via `ColdLogic.openCredit` if it was at least 10 s and shows "Recovered m:ss". The FIT activity is not recoverable.
- `monkeyc -l 3` (strict typecheck) must build clean for fr965 and fr255s.
- Touch stays disabled everywhere; add new delegates by extending `KeyDelegate`.
- Keep long `&&` chains in tests split into named variables (compiler OOM otherwise).
- Never commit or print signing keys. Signing key: `~/.garmin-keys/ColdStartDeveloperKey.der` (PEM beside it, mode 600). Reuse it for updates and keep a backup. CI secret `COLDSTART_DEV_KEY` is the base64 of the DER file. Device files come from this repo's draft `ci-devices` release (`ciq-devices.zip`, copied from NextSet), read with the workflow token.
- Simulator results are not device results; record them separately in `docs/DEVICE_TESTS.md`.
