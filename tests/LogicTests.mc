import Toybox.Lang;
import Toybox.Test;

function check(logger as Test.Logger, condition as Boolean, message as String) as Boolean {
    if (!condition) {
        logger.error(message);
        return false;
    }
    return true;
}

// 2026-01-05 is a Monday; day index below is computed from the calendar, not hard-coded guesses.
const D_MON = 20458;  // 2026-01-05 (Mon)

(:test)
function testTargetClampAndSteps(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.clampTarget(0) == 15, "clamp low");
    ok = ok && check(logger, ColdLogic.clampTarget(5000) == 900, "clamp high");
    ok = ok && check(logger, ColdLogic.clampTarget(120) == 120, "clamp inside");
    ok = ok && check(logger, ColdLogic.stepTarget(120, 1) == 135, "step up");
    ok = ok && check(logger, ColdLogic.stepTarget(120, -1) == 105, "step down");
    ok = ok && check(logger, ColdLogic.stepTarget(15, -1) == 15, "floor at 0:15");
    ok = ok && check(logger, ColdLogic.stepTarget(900, 1) == 900, "ceiling at 15:00");
    ok = ok && check(logger, ColdLogic.stepTarget(100, 1) == 105, "odd value snaps up");
    ok = ok && check(logger, ColdLogic.stepTarget(100, -1) == 90, "odd value snaps down");
    ok = ok && check(logger, ColdLogic.stepTarget(0, 1) == 30, "bad stored value is clamped first");
    return ok;
}

(:test)
function testCountdownFormatting(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.formatClock(0).equals("0:00"), "zero");
    ok = ok && check(logger, ColdLogic.formatClock(125).equals("2:05"), "125 s");
    ok = ok && check(logger, ColdLogic.formatClock(900).equals("15:00"), "15 min");
    ok = ok && check(logger, ColdLogic.countdownText(0, 120).equals("2:00"), "start");
    ok = ok && check(logger, ColdLogic.countdownText(119, 120).equals("0:01"), "last second");
    ok = ok && check(logger, ColdLogic.countdownText(120, 120).equals("0:00"), "at target");
    ok = ok && check(logger, ColdLogic.countdownText(132, 120).equals("+0:12"), "overtime");
    ok = ok && check(logger, ColdLogic.countdownText(190, 120).equals("+1:10"), "overtime minute");
    ok = ok && check(logger, !ColdLogic.isOvertime(120, 120), "not overtime at target");
    ok = ok && check(logger, ColdLogic.isOvertime(121, 120), "overtime after target");
    ok = ok && check(logger, ColdLogic.progress(60, 120) == 0.5, "half progress");
    ok = ok && check(logger, ColdLogic.progress(500, 120) == 1.0, "progress clamps");
    return ok;
}

(:test)
function testVibrationSchedule(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.vibeAt(0, 120) == ColdLogic.VIBE_NONE, "nothing at 0");
    ok = ok && check(logger, ColdLogic.vibeAt(29, 120) == ColdLogic.VIBE_NONE, "nothing at 29");
    ok = ok && check(logger, ColdLogic.vibeAt(30, 120) == ColdLogic.VIBE_PULSE, "pulse at 30");
    ok = ok && check(logger, ColdLogic.vibeAt(90, 120) == ColdLogic.VIBE_PULSE, "pulse at 90");
    ok = ok && check(logger, ColdLogic.vibeAt(120, 120) == ColdLogic.VIBE_TARGET, "long at target");
    ok = ok && check(logger, ColdLogic.vibeAt(150, 120) == ColdLogic.VIBE_PULSE, "pulse in overtime");
    ok = ok && check(logger, ColdLogic.vibeAt(45, 45) == ColdLogic.VIBE_TARGET, "target off the 30 s grid");
    ok = ok && check(logger, ColdLogic.vibeAt(60, 45) == ColdLogic.VIBE_PULSE, "pulse after odd target");
    ok = ok && check(logger, ColdLogic.vibeBetween(28, 29, 120) == ColdLogic.VIBE_NONE, "tick without event");
    ok = ok && check(logger, ColdLogic.vibeBetween(29, 30, 120) == ColdLogic.VIBE_PULSE, "tick onto 30");
    ok = ok && check(logger, ColdLogic.vibeBetween(118, 121, 120) == ColdLogic.VIBE_TARGET, "late tick keeps the target alert");
    ok = ok && check(logger, ColdLogic.vibeBetween(119, 120, 15) == ColdLogic.VIBE_PULSE, "pulse, target long passed");
    var count = 0;
    for (var s = 1; s <= 300; s++) {
        if (ColdLogic.vibeAt(s, 120) != ColdLogic.VIBE_NONE) {
            count++;
        }
    }
    ok = ok && check(logger, count == 10, "10 events in 300 s");
    return ok;
}

(:test)
function testCalendar(logger as Test.Logger) as Boolean {
    // Local midnight: 23:30 and 00:30 local fall on different days.
    var offset = 7200;
    var lateUtc = (D_MON * 86400) - offset + 23 * 3600 + 1800;
    var ok = check(logger, ColdLogic.dayIndex(lateUtc, offset) == D_MON, "23:30 local");
    ok = ok && check(logger, ColdLogic.dayIndex(lateUtc + 3600, offset) == D_MON + 1, "00:30 local next day");
    ok = ok && check(logger, ColdLogic.dayIndex(0, 0) == 0, "epoch is day 0");
    ok = ok && check(logger, ColdLogic.dayIndex(-1, 0) == -1, "floor for negative times");
    return ok;
}

(:test)
function testStreak(logger as Test.Logger) as Boolean {
    var s = ColdLogic.emptyStats();
    var ok = check(logger, ColdLogic.currentStreak(s, D_MON) == 0, "empty streak");
    s = ColdLogic.recordShower(s, D_MON, 90);
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON) == 1, "one day");
    s = ColdLogic.recordShower(s, D_MON, 90);
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON) == 1, "second shower same day");
    s = ColdLogic.recordShower(s, D_MON + 1, 90);
    s = ColdLogic.recordShower(s, D_MON + 2, 90);
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON + 2) == 3, "three consecutive days");
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON + 3) == 3, "today without shower keeps streak");
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON + 4) == 0, "missed a full day breaks it");
    s = ColdLogic.recordShower(s, D_MON + 5, 90);
    ok = ok && check(logger, ColdLogic.currentStreak(s, D_MON + 5) == 1, "restart after a gap");
    ok = ok && check(logger, (s["lastSec"] as Number) == 90, "last duration is stored");
    s = ColdLogic.recordShower(s, D_MON + 5, 135);
    ok = ok && check(logger, (s["lastSec"] as Number) == 135, "last duration follows the newest shower");
    // Out-of-order save (clock moved back) keeps the streak and the last day.
    var o = ColdLogic.recordShower(ColdLogic.emptyStats(), D_MON + 3, 90);
    o = ColdLogic.recordShower(o, D_MON + 1, 90);
    ok = ok && check(logger, (o["last"] as Number) == D_MON + 3 && (o["streak"] as Number) == 1, "out-of-order");
    return ok;
}

(:test)
function testStatsValidation(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.validStats(ColdLogic.emptyStats() as Object?), "valid stats");
    ok = ok && check(logger, !ColdLogic.validStats(null), "null rejected");
    ok = ok && check(logger, !ColdLogic.validStats({"last" => 1} as Object?), "partial rejected");
    ok = ok && check(logger, !ColdLogic.validStats({"last" => "x", "streak" => 1, "lastSec" => 1} as Object?), "wrong type rejected");
    return ok;
}

(:test)
function testBaselineMedian(logger as Test.Logger) as Boolean {
    var buf = [] as Array<Number>;
    var ok = check(logger, ShockLogic.median(buf) == null, "empty median is null");
    buf = ShockLogic.pushSample(buf, 70);
    buf = ShockLogic.pushSample(buf, 0);
    buf = ShockLogic.pushSample(buf, null);
    buf = ShockLogic.pushSample(buf, 300);
    ok = ok && check(logger, buf.size() == 1, "invalid samples ignored");
    buf = ShockLogic.pushSample(buf, 90);
    buf = ShockLogic.pushSample(buf, 60);
    ok = ok && check(logger, ShockLogic.median(buf) == 70, "odd median");
    buf = ShockLogic.pushSample(buf, 80);
    ok = ok && check(logger, ShockLogic.median(buf) == 75, "even median");
    for (var i = 0; i < 20; i++) {
        buf = ShockLogic.pushSample(buf, 100 + i);
    }
    ok = ok && check(logger, buf.size() == 10 && buf[0] == 110, "rolling window of 10");
    ok = ok && check(logger, ShockLogic.median(buf) == 115, "median of newest samples");
    return ok;
}

(:test)
function testShockPeakAndCalm(logger as Test.Logger) as Boolean {
    var t = new ShockTracker(60);
    for (var s = 1; s <= 5; s++) {
        t.onSecond(s, 60 + s * 12);
    }
    // Peak 120 at second 5, then it falls; within rest+10 = 70 from second 20 on.
    for (var s = 6; s <= 19; s++) {
        t.onSecond(s, 100);
    }
    var ok = check(logger, t.peak == 120, "peak is the max");
    ok = ok && check(logger, t.calm == null, "not calm while above the band");
    for (var s = 20; s <= 35; s++) {
        t.onSecond(s, 68);
    }
    ok = ok && check(logger, t.calm == 20, "calm = start of the first 10 s stay");
    // A peak after 60 s does not count.
    t.onSecond(70, 200);
    ok = ok && check(logger, t.peak == 120, "peak window is the first 60 s");

    var n = new ShockTracker(60);
    for (var s = 1; s <= 120; s++) {
        n.onSecond(s, s % 5 == 0 ? 65 : 110);
    }
    ok = ok && check(logger, n.peak == 110 && n.calm == null, "never calm: a brief dip is not enough");

    var gap = new ShockTracker(60);
    gap.onSecond(1, 120);
    for (var s = 2; s <= 8; s++) {
        gap.onSecond(s, 65);
    }
    gap.onSecond(9, null);
    for (var s = 10; s <= 18; s++) {
        gap.onSecond(s, 65);
    }
    ok = ok && check(logger, gap.calm == null, "missing HR breaks the stay");
    gap.onSecond(19, 65);
    ok = ok && check(logger, gap.calm == 10, "stay of 10 s after the gap");

    var none = new ShockTracker(null);
    none.onSecond(1, 120);
    ok = ok && check(logger, none.peak == null && none.calm == null, "no baseline, no shock values");
    return ok;
}

(:test)
function testHrvFilteringAndRmssd(logger as Test.Logger) as Boolean {
    var h = new HrvTracker();
    h.addInterval(100);
    h.addInterval(2500);
    var ok = check(logger, h.rmssd() == null, "out-of-range intervals dropped");
    // 800, 820, 800, 820 ... successive differences are all 20 ms: RMSSD 20.
    for (var i = 0; i < 12; i++) {
        h.addInterval(i % 2 == 0 ? 800 : 820);
    }
    ok = ok && check(logger, h.rmssd() == 20, "RMSSD of alternating 800/820 is 20");
    // A 40 % jump is an artifact and is skipped without changing the reference.
    h.addInterval(1150);
    h.addInterval(800);
    ok = ok && check(logger, h.rmssd() != null, "artifact rejected");
    var h2 = new HrvTracker();
    h2.addInterval(1000);
    h2.addInterval(1200);
    h2.addInterval(1000);
    // 1200 is exactly +20 %: kept; differences 200 and 200 -> too few for a value.
    ok = ok && check(logger, h2.rmssd() == null, "needs 10 differences");
    var diffs = new HrvTracker();
    diffs.addInterval(1000);
    for (var i = 0; i < 10; i++) {
        diffs.addInterval(i % 2 == 0 ? 1100 : 1000);
    }
    ok = ok && check(logger, diffs.rmssd() == 100, "known RMSSD of 1000/1100");
    // A drift larger than 20 % that persists is accepted as the new reference after 5 drops.
    var shift = new HrvTracker();
    shift.addInterval(500);
    for (var i = 0; i < 5; i++) {
        shift.addInterval(900);
    }
    shift.addInterval(905);
    ok = ok && check(logger, shift.rmssd() == null, "reference reset after repeated rejects");
    return ok;
}

(:test)
function testHrvWindowsAndFitMapping(logger as Test.Logger) as Boolean {
    var h = new HrvTracker();
    var ok = check(logger, !h.closeIfDue(29), "window not due at 29 s");
    // 11 intervals in the first window.
    for (var i = 0; i < 11; i++) {
        h.addInterval(i % 2 == 0 ? 800 : 840);
    }
    ok = ok && check(logger, h.closeIfDue(30), "window closes at 30 s");
    ok = ok && check(logger, h.lastWindow == 40, "valid window RMSSD");
    ok = ok && check(logger, !h.closeIfDue(31), "only once per window");
    // Window 2 has only 5 intervals: invalid.
    for (var i = 0; i < 5; i++) {
        h.addInterval(i % 2 == 0 ? 800 : 840);
    }
    ok = ok && check(logger, h.closeIfDue(60) && h.lastWindow == null, "sparse window is invalid");
    ok = ok && check(logger, ShockLogic.fitByte(null) == 255 && ShockLogic.fitByte(64) == 64, "uint8 mapping");
    ok = ok && check(logger, ShockLogic.fitWord(null) == 65535 && ShockLogic.fitWord(45) == 45, "uint16 mapping");
    ok = ok && check(logger, ShockLogic.fitWord(-1) == 65535 && ShockLogic.fitByte(300) == 255, "out of range is invalid");
    return ok;
}
