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
    private var _dayIndex as Number = 0;
    private var _lastStartPressAt as Number = -10000;
    private var _tickCount as Number = 0;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;
    private var _baseline as Array<Number> = [] as Array<Number>;
    private var _shock as ShockTracker = new ShockTracker(null);
    private var _hrv as HrvTracker = new HrvTracker();
    private var _listening as Boolean = false;
    private var _pendingHrv as Number? = null;

    public var target as Number = ColdLogic.TARGET_DEFAULT;
    public var stats as Dictionary = ColdLogic.emptyStats();
    public var elapsed as Number = 0;
    public var lastVibe as Number = 0;
    public var hrNow as Number = 0;
    public var hrMax as Number = 0;
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
    }

    // A shower that is still open when the app stops is saved as it is (not lost).
    public function onStop(state as Dictionary?) as Void {
        stopTimer();
        stopHrvListener();
        if (_state == STATE_RUNNING) {
            elapsed = Time.now().value() - _startedAt;
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

    // --- Baseline (Home, 1 s) and shock/HRV results ---------------------------------------------

    public function clearBaseline() as Void {
        _baseline = [] as Array<Number>;
    }

    // Called by the Home timer; rolling window of the last 10 valid samples.
    public function sampleBaseline() as Void {
        if (_state == STATE_IDLE) {
            _baseline = ShockLogic.pushSample(_baseline, readHeartRate());
        }
    }

    public function baselineHr() as Number? {
        return ShockLogic.median(_baseline);
    }

    public function restHr() as Number? {
        return _shock.rest;
    }

    public function peakHr() as Number? {
        return _shock.peak;
    }

    public function calmSec() as Number? {
        return _shock.calm;
    }

    public function hrvRmssd() as Number? {
        return _hrv.rmssd();
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
        _dayIndex = ColdLogic.dayIndex(_startedAt, ColdStore.localOffset(now));
        elapsed = 0;
        lastVibe = 0;
        hrNow = 0;
        hrMax = 0;
        _hrSum = 0;
        _hrCount = 0;
        _tickCount = 0;
        _shock = new ShockTracker(ShockLogic.median(_baseline));
        _hrv = new HrvTracker();
        _pendingHrv = null;
        startHrvListener();
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
        stopHrvListener();
        elapsed = Time.now().value() - _startedAt;
        _recorder.stop();
        _state = STATE_REVIEW;
    }

    // Saves the FIT session and updates the stats. Returns false (staying in review) on failure.
    public function saveShower() as Boolean {
        if (_state != STATE_REVIEW) {
            return false;
        }
        _recorder.setShockSummary(_shock.rest, _shock.peak, _shock.calm, _hrv.rmssd());
        if (!_recorder.save()) {
            return false;
        }
        stats = ColdLogic.recordShower(stats, _dayIndex, elapsed);
        ColdStore.saveStats(stats);
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
        stopHrvListener();
        _state = STATE_IDLE;
        notice = "Discarded";
        return true;
    }

    public function hrAverage() as Number {
        return _hrCount > 0 ? _hrSum / _hrCount : 0;
    }

    public function hasHr() as Boolean {
        return _hrCount > 0;
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
        elapsed = Time.now().value() - _startedAt;
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
        var hr = sampleHeartRate();
        _shock.onSecond(elapsed, hr);
        // HRV window closed on the previous tick goes into this tick's record (or invalid).
        _recorder.setHrv30(_pendingHrv);
        _pendingHrv = null;
        if (_hrv.closeIfDue(elapsed)) {
            _pendingHrv = _hrv.lastWindow;
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
            if (info != null && ShockLogic.validHr(info.currentHeartRate)) {
                return info.currentHeartRate as Number;
            }
        } catch (error) {
        }
        try {
            if (Sensor has :getInfo) {
                var sensorInfo = Sensor.getInfo();
                if (sensorInfo != null && ShockLogic.validHr(sensorInfo.heartRate)) {
                    return sensorInfo.heartRate as Number;
                }
            }
        } catch (error) {
        }
        return null;
    }

    private function sampleHeartRate() as Number? {
        var hr = readHeartRate();
        if (hr != null) {
            hrNow = hr;
            _hrSum += hr;
            _hrCount++;
            if (hr > hrMax) {
                hrMax = hr;
            }
        }
        return hr;
    }

    private function startHrvListener() as Void {
        try {
            if (Sensor has :registerSensorDataListener) {
                Sensor.registerSensorDataListener(method(:onSensorData),
                    {:period => 1, :heartBeatIntervals => {:enabled => true}});
                _listening = true;
            }
        } catch (error) {
            _listening = false;
        }
    }

    private function stopHrvListener() as Void {
        if (!_listening) {
            return;
        }
        _listening = false;
        try {
            Sensor.unregisterSensorDataListener();
        } catch (error) {
        }
    }

    // Public: sensor callbacks must be public. Only adds to running sums.
    public function onSensorData(data as Sensor.SensorData) as Void {
        if (_state != STATE_RUNNING) {
            return;
        }
        try {
            var hrData = data.heartRateData;
            if (hrData == null) {
                return;
            }
            var intervals = hrData.heartBeatIntervals;
            if (intervals == null) {
                return;
            }
            for (var i = 0; i < intervals.size(); i++) {
                _hrv.addInterval(intervals[i]);
            }
        } catch (error) {
        }
    }
}

function getApp() as ColdStartApp {
    return Application.getApp() as ColdStartApp;
}
