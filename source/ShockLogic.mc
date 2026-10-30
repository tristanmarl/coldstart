import Toybox.Lang;
import Toybox.Math;

// Pure logic for the cold-shock response (from heart rate) and HRV (RMSSD from beat intervals).
module ShockLogic {
    const HR_MIN = 30;
    const HR_MAX = 250;
    const BASELINE_SAMPLES = 10;
    const PEAK_WINDOW_SEC = 60;
    const CALM_BAND = 10;
    const CALM_HOLD_SEC = 10;
    const IVL_MIN_MS = 300;
    const IVL_MAX_MS = 2000;
    const IVL_JUMP_PERCENT = 20;
    const IVL_MAX_REJECTS = 5;
    const WINDOW_SEC = 30;
    const WINDOW_MIN_INTERVALS = 10;
    const FIT_INVALID_UINT8 = 255;
    const FIT_INVALID_UINT16 = 65535;

    function validHr(hr as Number?) as Boolean {
        return hr != null && hr >= HR_MIN && hr <= HR_MAX;
    }

    // Returns a new buffer with the sample appended (invalid samples ignored), newest 10 kept.
    function pushSample(buffer as Array<Number>, hr as Number?) as Array<Number> {
        if (!validHr(hr)) {
            return buffer;
        }
        var out = buffer.slice(null, null) as Array<Number>;
        out.add(hr as Number);
        while (out.size() > BASELINE_SAMPLES) {
            out = out.slice(1, null) as Array<Number>;
        }
        return out;
    }

    // Median of the samples (mean of the two middle ones, rounded, for an even count); null when empty.
    function median(buffer as Array<Number>) as Number? {
        var n = buffer.size();
        if (n == 0) {
            return null;
        }
        var sorted = buffer.slice(null, null) as Array<Number>;
        for (var i = 1; i < n; i++) {
            var v = sorted[i];
            var j = i - 1;
            while (j >= 0 && sorted[j] > v) {
                sorted[j + 1] = sorted[j];
                j--;
            }
            sorted[j + 1] = v;
        }
        if (n % 2 == 1) {
            return sorted[n / 2];
        }
        return (sorted[n / 2 - 1] + sorted[n / 2] + 1) / 2;
    }

    // Null (not measured) becomes the FIT "invalid" value of the field type.
    function fitByte(value as Number?) as Number {
        return (value == null || value < 0 || value >= FIT_INVALID_UINT8) ? FIT_INVALID_UINT8 : value;
    }

    function fitWord(value as Number?) as Number {
        return (value == null || value < 0 || value >= FIT_INVALID_UINT16) ? FIT_INVALID_UINT16 : value;
    }
}

// Peak HR in the first 60 s and the time until HR settles back near the resting baseline.
// Needs a baseline: without one every value stays null.
class ShockTracker {
    public var rest as Number? = null;
    public var peak as Number? = null;
    public var calm as Number? = null;
    private var _peakAt as Number = -1;
    private var _run as Number = 0;
    private var _lastSec as Number = -1;

    public function initialize(restHr as Number?) {
        rest = restHr;
    }

    // Call once per elapsed second with the current HR (null when unknown).
    public function onSecond(sec as Number, hr as Number?) as Void {
        if (rest == null || sec <= _lastSec) {
            return;
        }
        _lastSec = sec;
        if (!ShockLogic.validHr(hr)) {
            _run = 0;
            return;
        }
        var value = hr as Number;
        if (sec <= ShockLogic.PEAK_WINDOW_SEC && (peak == null || value > (peak as Number))) {
            // A new, higher peak restarts the calm search.
            peak = value;
            _peakAt = sec;
            _run = 0;
            calm = null;
            return;
        }
        if (calm != null || _peakAt < 0 || sec <= _peakAt) {
            return;
        }
        if (value <= (rest as Number) + ShockLogic.CALM_BAND) {
            _run++;
            if (_run >= ShockLogic.CALM_HOLD_SEC) {
                // Start of the first 10 s stay within the band.
                calm = sec - ShockLogic.CALM_HOLD_SEC + 1;
            }
        } else {
            _run = 0;
        }
    }
}

// Running RMSSD of accepted beat intervals: whole shower plus one value per 30 s window.
// Only sums are kept, no growing arrays.
class HrvTracker {
    // Window RMSSD (ms) closed most recently; null when that window was invalid.
    public var lastWindow as Number? = null;
    private var _prev as Number = 0;
    private var _rejects as Number = 0;
    private var _sumSq as Float = 0.0;
    private var _diffs as Number = 0;
    private var _wSumSq as Float = 0.0;
    private var _wDiffs as Number = 0;
    private var _wCount as Number = 0;
    private var _winIndex as Number = 0;

    public function initialize() {
    }

    // One beat interval in ms. Keeps 300-2000 ms and drops intervals that jump more than 20 %
    // from the previous accepted one; after 5 drops in a row the next one becomes the new reference.
    public function addInterval(ms as Number) as Void {
        if (ms < ShockLogic.IVL_MIN_MS || ms > ShockLogic.IVL_MAX_MS) {
            return;
        }
        if (_prev > 0 && (ms - _prev).abs() * 100 > _prev * ShockLogic.IVL_JUMP_PERCENT) {
            _rejects++;
            if (_rejects >= ShockLogic.IVL_MAX_REJECTS) {
                _prev = ms;
                _rejects = 0;
            }
            return;
        }
        _rejects = 0;
        if (_prev > 0) {
            var d = (ms - _prev).toFloat();
            _sumSq += d * d;
            _diffs++;
            _wSumSq += d * d;
            _wDiffs++;
        }
        _wCount++;
        _prev = ms;
    }

    // Call each second with the elapsed time; closes the 30 s window when it is over.
    // Returns true when a window was closed (its value is then in lastWindow, null if invalid).
    public function closeIfDue(sec as Number) as Boolean {
        var index = sec / ShockLogic.WINDOW_SEC;
        if (index <= _winIndex) {
            return false;
        }
        if (_wCount >= ShockLogic.WINDOW_MIN_INTERVALS && _wDiffs > 0) {
            lastWindow = round(_wSumSq / _wDiffs.toFloat());
        } else {
            lastWindow = null;
        }
        _wSumSq = 0.0;
        _wDiffs = 0;
        _wCount = 0;
        _winIndex = index;
        return true;
    }

    // Whole-shower RMSSD in ms; null with fewer than 10 successive differences.
    public function rmssd() as Number? {
        if (_diffs < ShockLogic.WINDOW_MIN_INTERVALS) {
            return null;
        }
        return round(_sumSq / _diffs.toFloat());
    }

    private function round(meanSquare as Float) as Number {
        return (Math.sqrt(meanSquare) + 0.5).toNumber();
    }
}
