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

    private var _state as Number = 0;
    private var _recorder as ShowerRecorder;
    private var _timer as Timer.Timer;
    private var _timerStarted as Boolean = false;
    private var _startedAt as Number = 0;
    private var _startMs as Number = 0;
    private var _dayIndex as Number = 0;
    private var _lastStartPressAt as Number = -10000;
    private var _tickCount as Number = 0;
    private var _hr as HrTracker = new HrTracker();

    public var target as Number = ColdLogic.TARGET_DEFAULT;
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
        stats = ColdStore.loadStats();
        recoverOpenShower();
    }

    // A shower that is still open when the app stops is saved as it is (not lost).
    public function onStop(state as Dictionary?) as Void {
        stopTimer();
        if (_state == STATE_RUNNING) {
            elapsed = ColdLogic.elapsedSec(_startMs, System.getTimer());
            _recorder.stop();
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

    public function startShower() as Boolean {
        if (_state != STATE_IDLE) {
            return false;
        }
        notice = null;
        if (!_recorder.start(target)) {
            notice = "Can't record";
            return false;
        }
        var now = Time.now();
        _startedAt = now.value();
        _startMs = System.getTimer();
        _dayIndex = ColdLogic.dayIndex(_startedAt, ColdStore.localOffset(now));
        elapsed = 0;
        lastVibe = 0;
        hrNow = 0;
        _hr = new HrTracker();
        _tickCount = 0;
        ColdStore.saveOpen([_startedAt, _dayIndex, target, 0] as Array<Number>);
        _state = STATE_RUNNING;
        _timer.start(method(:onTick), 1000, true);
        _timerStarted = true;
        keepScreenOn();
        return true;
    }

    public function stopShower() as Void {
        if (_state != STATE_RUNNING) {
            return;
        }
        stopTimer();
        elapsed = ColdLogic.elapsedSec(_startMs, System.getTimer());
        _recorder.stop();
        _state = STATE_REVIEW;
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
        elapsed = ColdLogic.elapsedSec(_startMs, System.getTimer());
        _tickCount++;
        var vibe = ColdLogic.vibeBetween(previous, elapsed, target);
        if (vibe != ColdLogic.VIBE_NONE && (Attention has :vibrate)) {
            try {
                if (vibe == ColdLogic.VIBE_TARGET) {
                    Attention.vibrate([new Attention.VibeProfile(100, 600),
                        new Attention.VibeProfile(0, 150), new Attention.VibeProfile(100, 600),
                        new Attention.VibeProfile(0, 150), new Attention.VibeProfile(100, 600)]);
                } else {
                    Attention.vibrate([new Attention.VibeProfile(60, 200)]);
                }
            } catch (error) {
            }
        }
        sampleHeartRate();
        // Crash-recovery checkpoint 15 s after each vibration second (never in a vibrating tick).
        if (vibe == ColdLogic.VIBE_NONE && ColdLogic.checkpointDue(elapsed)) {
            ColdStore.saveOpen([_startedAt, _dayIndex, target, elapsed] as Array<Number>);
        }
        if (_tickCount % 10 == 0) {
            keepScreenOn();
        }
        WatchUi.requestUpdate();
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
