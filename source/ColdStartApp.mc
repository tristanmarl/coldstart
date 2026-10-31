import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Owns the shower state machine, the 1 s timer, the recorder and the persisted data.
class ColdStartApp extends Application.AppBase {
    public const STATE_IDLE = 0;
    public const STATE_RUNNING = 1;
    public const STATE_REVIEW = 2;
    public const STATE_PAUSED = 3;

    private var _state as Number = 0;
    private var _recorder as ShowerRecorder;
    private var _timer as Timer.Timer;
    private var _timerStarted as Boolean = false;
    private var _startedAt as Number = 0;
    private var _runStartMs as Number = 0;
    private var _activeMs as Number = 0;
    private var _dayIndex as Number = 0;
    private var _lastStartPressAt as Number = -10000;
    private var _tickCount as Number = 0;
    private var _sinceLight as Number = 0;
    private var _alertRepeatAt as Number = 0;
    private var _hr as HrTracker = new HrTracker();

    public var target as Number = ColdLogic.TARGET_DEFAULT;
    public var sessionType as Number = ColdLogic.TYPE_SHOWER;
    public var stats as Dictionary = ColdLogic.emptyStats();
    public var elapsed as Number = 0;
    public var lastVibe as Number = 0;
    public var hrNow as Number = 0;
    // One-shot message on Home (e.g. "Saved").
    public var notice as String? = null;

    public function initialize() {
        AppBase.initialize();
        _recorder = new ShowerRecorder();
        _timer = new Timer.Timer();
    }

    public function onStart(state as Dictionary?) as Void {
        AppBase.onStart(state);
        target = ColdStore.loadTarget();
        sessionType = ColdStore.loadType();
        stats = ColdStore.loadStats();
        recoverOpenShower();
    }

    // A shower that is still open when the app stops is saved as it is (not lost).
    public function onStop(state as Dictionary?) as Void {
        stopTimer();
        if (_state == STATE_RUNNING) {
            elapsed = currentElapsed();
            _recorder.stop();
            _state = STATE_REVIEW;
        } else if (_state == STATE_PAUSED) {
            _state = STATE_REVIEW;
        }
        if (_state == STATE_REVIEW) {
            if (elapsed >= ColdLogic.MIN_SAVE_SEC) {
                saveShower();
            } else {
                discardShower();
            }
        }
        AppBase.onStop(state);
    }

    // A shower still marked open at launch means the app died without onStop: credit the streak
    // day and last duration from the last checkpoint. The FIT activity itself is not recoverable.
    private function recoverOpenShower() as Void {
        var credit = ColdLogic.openCredit(ColdStore.loadOpen());
        ColdStore.clearOpen();
        if (credit != null) {
            stats = ColdLogic.recordShower(stats, (credit as Array<Number>)[0],
                (credit as Array<Number>)[1]);
            ColdStore.saveStats(stats);
            notice = "Recovered " + ColdLogic.formatClock((credit as Array<Number>)[1]);
        }
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new HomeView();
        return [view, new HomeDelegate(view)];
    }

    public function state() as Number {
        return _state;
    }

    // Both START actions (begin / stop) go through this guard: a second press within 800 ms is ignored.
    public function acceptStart() as Boolean {
        var now = System.getTimer();
        if (now - _lastStartPressAt < 800) {
            return false;
        }
        _lastStartPressAt = now;
        return true;
    }

    // Heart-rate summary of the shower (valid samples only); null when there was none.
    public function hrMin() as Number? {
        return _hr.min;
    }

    public function hrMax() as Number? {
        return _hr.max;
    }

    public function hrAverage() as Number? {
        return _hr.average();
    }

    public function adjustTarget(direction as Number) as Void {
        target = ColdLogic.stepTarget(target, direction);
        ColdStore.saveTarget(target);
        notice = null;
    }

    // Hold UP on Home: the type is fixed for a session once it has started.
    public function toggleType() as Void {
        if (_state != STATE_IDLE) {
            return;
        }
        sessionType = ColdLogic.toggleType(sessionType);
        ColdStore.saveType(sessionType);
        notice = null;
    }

    public function startShower() as Boolean {
        if (_state != STATE_IDLE) {
            return false;
        }
        notice = null;
        if (!_recorder.start(target, ColdLogic.typeName(sessionType))) {
            notice = "Can't record";
            return false;
        }
        var now = Time.now();
        _startedAt = now.value();
        _runStartMs = System.getTimer();
        _activeMs = 0;
        _dayIndex = ColdLogic.dayIndex(_startedAt, ColdStore.localOffset(now));
        elapsed = 0;
        lastVibe = 0;
        hrNow = 0;
        _hr = new HrTracker();
        _tickCount = 0;
        _sinceLight = 0;
        _alertRepeatAt = 0;
        ColdStore.saveOpen([_startedAt, _dayIndex, target, 0] as Array<Number>);
        _state = STATE_RUNNING;
        _timer.start(method(:onTick), 1000, true);
        _timerStarted = true;
        keepScreenOn();
        return true;
    }

    // Active (not paused) seconds of the session.
    private function currentElapsed() as Number {
        return ColdLogic.activeSec(_activeMs, _runStartMs, System.getTimer(), _state == STATE_RUNNING);
    }

    // START during a session pauses it (an accidental press can be undone): the 1 s counting stops,
    // the Garmin activity is stopped but stays open, and the frozen active time is kept.
    public function pauseShower() as Boolean {
        if (_state != STATE_RUNNING) {
            return false;
        }
        stopTimer();
        _activeMs = ColdLogic.activeMs(_activeMs, _runStartMs, System.getTimer(), true);
        elapsed = _activeMs / 1000;
        _alertRepeatAt = 0;
        _recorder.stop();
        _state = STATE_PAUSED;
        feedback();
        return true;
    }

    // Resumes recording and counting; the target alert and pulses continue from the active time.
    public function resumeShower() as Boolean {
        if (_state != STATE_PAUSED) {
            return false;
        }
        if (!_recorder.resume()) {
            notice = "Can't resume";
            return false;
        }
        _runStartMs = System.getTimer();
        _state = STATE_RUNNING;
        _timer.start(method(:onTick), 1000, true);
        _timerStarted = true;
        keepScreenOn();
        feedback();
        return true;
    }

    // BACK on the Paused screen: finish and review.
    public function finishShower() as Void {
        if (_state != STATE_PAUSED) {
            return;
        }
        _state = STATE_REVIEW;
    }

    // Short single vibration confirming a pause or resume (never inside the 1 s tick).
    private function feedback() as Void {
        try {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 200)]);
            }
        } catch (error) {
        }
    }

    // Saves the FIT session and updates the stats. Returns false (staying in review) on failure.
    public function saveShower() as Boolean {
        if (_state != STATE_REVIEW) {
            return false;
        }
        if (!_recorder.save()) {
            return false;
        }
        stats = ColdLogic.recordShower(stats, _dayIndex, elapsed);
        ColdStore.saveStats(stats);
        ColdStore.clearOpen();
        _state = STATE_IDLE;
        notice = "Saved";
        return true;
    }

    public function discardShower() as Boolean {
        if (_state != STATE_REVIEW) {
            return false;
        }
        if (!_recorder.discard()) {
            return false;
        }
        ColdStore.clearOpen();
        _state = STATE_IDLE;
        notice = "Discarded";
        return true;
    }

    private function stopTimer() as Void {
        if (_timerStarted) {
            _timer.stop();
            _timerStarted = false;
        }
    }

    private function keepScreenOn() as Void {
        try {
            if (Attention has :backlight) {
                Attention.backlight(true);
            }
        } catch (error) {
        }
    }

    // Public: a private method(:...) callback compiles but fails on the watch.
    // Light tick: no storage writes here.
    public function onTick() as Void {
        if (_state != STATE_RUNNING) {
            stopTimer();
            return;
        }
        var previous = elapsed;
        elapsed = currentElapsed();
        _tickCount++;
        var step = ColdLogic.alertStep(previous, elapsed, target, _alertRepeatAt);
        var vibe = step[0];
        _alertRepeatAt = step[1];
        var vibrating = vibe != ColdLogic.VIBE_NONE;
        if (vibrating) {
            alert(vibe);
        }
        sampleHeartRate();
        // No storage write or backlight call in a vibrating tick. The crash-recovery checkpoint is
        // written 15 s after each pulse second.
        if (!vibrating && ColdLogic.checkpointDue(elapsed)) {
            ColdStore.saveOpen([_startedAt, _dayIndex, target, elapsed] as Array<Number>);
        }
        _sinceLight++;
        if (!vibrating && _sinceLight >= 10) {
            _sinceLight = 0;
            keepScreenOn();
        }
        WatchUi.requestUpdate();
    }

    // Single-profile vibrations (the pattern confirmed on the FR965): 1 s at full strength for the
    // target (and its repeat), 300 ms for the 30 s pulses. The tone goes with the repeat, not the
    // first target vibration, so a tone cannot cut that one short on watches with a beeper.
    private function alert(kind as Number) as Void {
        try {
            if (Attention has :vibrate) {
                if (kind == ColdLogic.VIBE_PULSE) {
                    Attention.vibrate([new Attention.VibeProfile(100, 300)]);
                } else {
                    Attention.vibrate([new Attention.VibeProfile(100, 1000)]);
                }
            }
        } catch (error) {
        }
        try {
            if (kind == ColdLogic.VIBE_REPEAT && (Attention has :playTone)) {
                Attention.playTone(Attention.TONE_ALERT_HI);
            }
        } catch (error) {
        }
    }

    // Current heart rate or null: Activity info first, then the sensor as fallback.
    private function readHeartRate() as Number? {
        try {
            var info = Activity.getActivityInfo();
            if (info != null && ColdLogic.validHr(info.currentHeartRate)) {
                return info.currentHeartRate as Number;
            }
        } catch (error) {
        }
        try {
            if (Sensor has :getInfo) {
                var sensorInfo = Sensor.getInfo();
                if (sensorInfo != null && ColdLogic.validHr(sensorInfo.heartRate)) {
                    return sensorInfo.heartRate as Number;
                }
            }
        } catch (error) {
        }
        return null;
    }

    private function sampleHeartRate() as Void {
        var hr = readHeartRate();
        if (hr != null) {
            hrNow = hr;
            _hr.add(hr);
        }
    }
}

function getApp() as ColdStartApp {
    return Application.getApp() as ColdStartApp;
}
