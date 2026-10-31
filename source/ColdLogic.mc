import Toybox.Lang;

// Pure logic (no UI, storage or clock access) so the unit tests can cover it.
module ColdLogic {
    const TARGET_MIN = 15;
    const TARGET_MAX = 900;
    const TARGET_STEP = 15;
    const TARGET_DEFAULT = 120;
    const PULSE_EVERY = 30;
    const MIN_SAVE_SEC = 10;
    const DAY_SEC = 86400;
    const HR_MIN = 30;
    const HR_MAX = 250;

    const VIBE_NONE = 0;
    const VIBE_PULSE = 1;
    const VIBE_TARGET = 2;
    const VIBE_REPEAT = 3;
    const ALERT_REPEAT_SEC = 2;
    const ALERT_SHOW_SEC = 5;

    function floorDiv(a as Number, b as Number) as Number {
        var q = a / b;
        if ((a % b != 0) && ((a < 0) != (b < 0))) {
            q -= 1;
        }
        return q;
    }

    // --- Target -------------------------------------------------------------------------------

    function clampTarget(sec as Number) as Number {
        if (sec < TARGET_MIN) {
            return TARGET_MIN;
        }
        return sec > TARGET_MAX ? TARGET_MAX : sec;
    }

    // One UP (direction > 0) or DOWN (direction < 0) step; odd stored values snap to the grid.
    function stepTarget(sec as Number, direction as Number) as Number {
        var base = clampTarget(sec);
        var rest = base % TARGET_STEP;
        var result = base;
        if (direction > 0) {
            result = base - rest + TARGET_STEP;
        } else if (direction < 0) {
            result = rest == 0 ? base - TARGET_STEP : base - rest;
        }
        return clampTarget(result);
    }

    // --- Formatting ---------------------------------------------------------------------------

    function formatClock(sec as Number) as String {
        var s = sec < 0 ? 0 : sec;
        return (s / 60).toString() + ":" + (s % 60).format("%02d");
    }

    function isOvertime(elapsed as Number, target as Number) as Boolean {
        return elapsed > target;
    }

    // Counts down to the target, then "+m:ss" overtime.
    function countdownText(elapsed as Number, target as Number) as String {
        var left = target - elapsed;
        return left >= 0 ? formatClock(left) : "+" + formatClock(-left);
    }

    // 0.0 .. 1.0 progress toward the target.
    function progress(elapsed as Number, target as Number) as Float {
        if (target <= 0 || elapsed <= 0) {
            return 0.0;
        }
        if (elapsed >= target) {
            return 1.0;
        }
        return elapsed.toFloat() / target.toFloat();
    }

    // --- Vibration schedule -------------------------------------------------------------------

    // Vibration due at exactly this elapsed second: a pulse every 30 s, a long one at the target.
    function vibeAt(sec as Number, target as Number) as Number {
        if (sec <= 0) {
            return VIBE_NONE;
        }
        if (sec == target) {
            return VIBE_TARGET;
        }
        // A pulse right after the target alert would cut its 1 s vibration short.
        if (sec > target && sec - target < ALERT_REPEAT_SEC + 1) {
            return VIBE_NONE;
        }
        return (sec % PULSE_EVERY == 0) ? VIBE_PULSE : VIBE_NONE;
    }

    // One vibration decision per tick: returns [kind, repeatAt]. The target alert fires once and
    // schedules a second identical one ALERT_REPEAT_SEC later (repeatAt, 0 = none) from a later
    // tick, so no timer is needed. Late ticks cannot lose or duplicate either alert.
    function alertStep(previous as Number, now as Number, target as Number,
                       repeatAt as Number) as Array<Number> {
        var kind = vibeBetween(previous, now, target);
        if (kind == VIBE_TARGET) {
            return [VIBE_TARGET, now + ALERT_REPEAT_SEC] as Array<Number>;
        }
        if (repeatAt > 0 && now >= repeatAt) {
            return [VIBE_REPEAT, 0] as Array<Number>;
        }
        return [kind, repeatAt] as Array<Number>;
    }

    // The Shower screen flashes "Target!" for the first few seconds after the target.
    function justReached(elapsed as Number, target as Number) as Boolean {
        return elapsed >= target && elapsed - target < ALERT_SHOW_SEC;
    }

    // Strongest vibration due in the seconds after `previous` up to and including `now`, so a
    // late tick does not lose the target alert. Looks back at most 60 s.
    function vibeBetween(previous as Number, now as Number, target as Number) as Number {
        var from = previous + 1;
        if (now - from > 60) {
            from = now - 60;
        }
        var result = VIBE_NONE;
        for (var s = from; s <= now; s++) {
            var kind = vibeAt(s, target);
            if (kind > result) {
                result = kind;
            }
        }
        return result;
    }

    // --- Calendar (days since 1970-01-01 in local time) ----------------------------------------

    function dayIndex(utcSec as Number, utcOffsetSec as Number) as Number {
        return floorDiv(utcSec + utcOffsetSec, DAY_SEC);
    }

    // --- Heart rate -----------------------------------------------------------------------------

    function validHr(hr as Number?) as Boolean {
        return hr != null && hr >= HR_MIN && hr <= HR_MAX;
    }

    // Heart-rate summary as three column strings [min, avg, max]; null when nothing was measured.
    function hrColumns(min as Number?, avg as Number?, max as Number?) as Array<String>? {
        if (min == null || avg == null || max == null) {
            return null;
        }
        return [min.toString(), avg.toString(), max.toString()] as Array<String>;
    }

    // --- Elapsed time and crash recovery ----------------------------------------------------------

    // Whole seconds between two System.getTimer() readings (ms, monotonic, wraps like int32);
    // never negative.
    function elapsedSec(startMs as Number, nowMs as Number) as Number {
        var delta = nowMs - startMs;
        return delta < 0 ? 0 : delta / 1000;
    }

    // The checkpoint is written 15 s after each vibration second, so a vibrating tick never writes.
    function checkpointDue(sec as Number) as Boolean {
        return sec > 0 && sec % PULSE_EVERY == PULSE_EVERY / 2;
    }

    // Open-shower record: [startedAtUtc, dayIndex, target, elapsedSec]. Returns [day, elapsedSec]
    // to credit when it is well-formed and at least MIN_SAVE_SEC long, else null.
    function openCredit(open as Object?) as Array<Number>? {
        if (!(open instanceof Array)) {
            return null;
        }
        var a = open as Array;
        if (a.size() != 4) {
            return null;
        }
        for (var i = 0; i < 4; i++) {
            if (!(a[i] instanceof Number)) {
                return null;
            }
        }
        var sec = a[3] as Number;
        if (sec < MIN_SAVE_SEC) {
            return null;
        }
        return [a[1] as Number, sec] as Array<Number>;
    }

    // --- Streak ---------------------------------------------------------------------------------
    // Stats dictionary: last (local day index of the last saved shower, or -1), streak and
    // lastSec (duration of the last saved shower, 0 before the first).

    function emptyStats() as Dictionary {
        return {"last" => -1, "streak" => 0, "lastSec" => 0};
    }

    // Returns a new stats dictionary with one saved shower on `day` added.
    function recordShower(stats as Dictionary, day as Number, sec as Number) as Dictionary {
        var last = stats["last"] as Number;
        var streak = stats["streak"] as Number;
        var newLast = last;
        var newStreak = streak;
        if (last < 0) {
            newStreak = 1;
            newLast = day;
        } else if (day == last + 1) {
            newStreak = streak + 1;
            newLast = day;
        } else if (day > last + 1) {
            newStreak = 1;
            newLast = day;
        } else if (newStreak < 1) {
            newStreak = 1;
        }
        return {"last" => newLast, "streak" => newStreak, "lastSec" => sec};
    }

    // Streak shown today: a run through yesterday still counts, older than that is broken.
    function currentStreak(stats as Dictionary, today as Number) as Number {
        var last = stats["last"] as Number;
        if (last < 0) {
            return 0;
        }
        return (today - last <= 1) ? stats["streak"] as Number : 0;
    }

    // Accepts a stored value only if it has the expected shape.
    function validStats(value as Object?) as Boolean {
        if (!(value instanceof Dictionary)) {
            return false;
        }
        var d = value as Dictionary;
        var keys = ["last", "streak", "lastSec"];
        for (var i = 0; i < keys.size(); i++) {
            if (!(d[keys[i]] instanceof Number)) {
                return false;
            }
        }
        return true;
    }
}

// Running min / max / average of the valid heart-rate samples of one shower (sums only).
class HrTracker {
    public var min as Number? = null;
    public var max as Number? = null;
    private var _sum as Number = 0;
    private var _count as Number = 0;

    public function initialize() {
    }

    // Samples outside 30-250 bpm (and null) are ignored.
    public function add(hr as Number?) as Void {
        if (!ColdLogic.validHr(hr)) {
            return;
        }
        var v = hr as Number;
        if (min == null || v < (min as Number)) {
            min = v;
        }
        if (max == null || v > (max as Number)) {
            max = v;
        }
        _sum += v;
        _count++;
    }

    // Rounded average; null without samples.
    public function average() as Number? {
        return _count > 0 ? (_sum + _count / 2) / _count : null;
    }
}
