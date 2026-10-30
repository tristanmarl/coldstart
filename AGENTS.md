# Repository Guidelines

## Project Structure

ColdStart is a Monkey C Connect IQ watch app (five-button Garmin watches, Connect IQ 5+, products in `manifest.xml`, reference device Forerunner 965). Pure logic is in `source/ColdLogic.mc` and `source/ShockLogic.mc`; storage, recorder and app state are in `source/`; screens are in `source/ui/`. Tests are in `tests/` (included through `tests.jungle`). Decisions are in `docs/SPEC.md`; build and device evidence belongs in `docs/`.

## Build, Test, and Run

Install Connect IQ SDK 9.2.0 and add its `bin` directory to `PATH`.

```sh
mkdir -p bin
monkeyc -f monkey.jungle -d fr965 -o bin/ColdStart.prg -y ~/.garmin-keys/ColdStartDeveloperKey.der
monkeydo bin/ColdStart.prg fr965
monkeyc --unit-test -f tests.jungle -d fr965 -o bin/ColdStart-tests.prg -y ~/.garmin-keys/ColdStartDeveloperKey.der
monkeydo bin/ColdStart-tests.prg fr965 -t   # without -t it launches as an app and hangs
```

Always pass `-y` to `monkeyc`, including simulator and unit-test builds. Or run `scripts/test.sh`. The SDK runner may exit 1 after reporting all tests passed: read the summary line.

## Style and Testing

Four spaces, typed parameters and returns, `UpperCamelCase` classes, `lowerCamelCase` functions and locals, `UPPER_SNAKE_CASE` constants. Tests are free functions marked `(:test)` taking `Test.Logger`; split long boolean chains into named variables and sequential `check` calls. Prefer focused changes.

Timer and sensor callbacks passed through `method(:callback)` must be public: a private one compiles but fails on the watch. Touch is disabled everywhere: every delegate extends `KeyDelegate`; do not use `Menu2`, confirmations or pickers in the shower flow. No storage writes in the vibration tick.

## Commits and Pull Requests

Short imperative subjects, such as `Fix target step`. Pull requests list build and test results and identify device checks that remain unverified.

## Security and Configuration

Signing key: `~/.garmin-keys/ColdStartDeveloperKey.der` (PEM source beside it). Never commit, upload or package either file; keep a backup and reuse the same key for updates. CI uses the `COLDSTART_DEV_KEY` secret (base64 of the DER) and `NEXTSET_RELEASES_TOKEN` (reads NextSet's `ci-devices` draft release). Do not check in SDK files or build artifacts (`bin/`).
