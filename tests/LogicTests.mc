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
function testHrTracker(logger as Test.Logger) as Boolean {
    var t = new HrTracker();
    var ok = check(logger, t.min == null && t.max == null && t.average() == null, "empty tracker");
    t.add(70);
    t.add(0);
    t.add(null);
    t.add(300);
    t.add(29);
    ok = ok && check(logger, t.min == 70 && t.max == 70 && t.average() == 70, "invalid samples ignored");
    t.add(62);
    t.add(118);
    t.add(30);
    t.add(250);
    ok = ok && check(logger, t.min == 30 && t.max == 250, "30 and 250 are valid bounds");
    var u = new HrTracker();
    u.add(62);
    u.add(75);
    u.add(80);
    ok = ok && check(logger, u.min == 62 && u.max == 80 && u.average() == 72, "min, max, rounded average");
    return ok;
}

(:test)
function testHrColumns(logger as Test.Logger) as Boolean {
    var cols = ColdLogic.hrColumns(62, 74, 118);
    var ok = check(logger, cols != null, "columns present");
    if (cols != null) {
        var c = cols as Array<String>;
        ok = ok && check(logger, c[0].equals("62") && c[1].equals("74") && c[2].equals("118"), "min, avg, max order");
    }
    ok = ok && check(logger, ColdLogic.hrColumns(null, null, null) == null, "hidden without HR");
    ok = ok && check(logger, ColdLogic.validHr(30) && ColdLogic.validHr(250), "valid range");
    ok = ok && check(logger, !ColdLogic.validHr(29) && !ColdLogic.validHr(251) && !ColdLogic.validHr(null), "invalid range");
    return ok;
}

// Runs the per-tick alert decision over a list of elapsed seconds; returns [targets, repeats,
// secondOfRepeat].
function runAlerts(ticks as Array<Number>, target as Number) as Array<Number> {
    var prev = 0;
    var repeatAt = 0;
    var targets = 0;
    var repeats = 0;
    var repeatSec = -1;
    for (var i = 0; i < ticks.size(); i++) {
        var step = ColdLogic.alertStep(prev, ticks[i], target, repeatAt);
        repeatAt = step[1];
        if (step[0] == ColdLogic.VIBE_TARGET) {
            targets++;
        } else if (step[0] == ColdLogic.VIBE_REPEAT) {
            repeats++;
            repeatSec = ticks[i];
        }
        prev = ticks[i];
    }
    return [targets, repeats, repeatSec] as Array<Number>;
}

function everySecond(last as Number) as Array<Number> {
    var out = [] as Array<Number>;
    for (var s = 1; s <= last; s++) {
        out.add(s);
    }
    return out;
}

(:test)
function testTargetAlertFiresOnce(logger as Test.Logger) as Boolean {
    var targets = [120, 135, 45, 30, 15] as Array<Number>;
    var ok = true;
    for (var i = 0; i < targets.size(); i++) {
        var r = runAlerts(everySecond(targets[i] + 40), targets[i]);
        ok = ok && check(logger, r[0] == 1, "one target alert for " + targets[i].toString());
        ok = ok && check(logger, r[1] == 1, "one repeat for " + targets[i].toString());
        ok = ok && check(logger, r[2] == targets[i] + 2, "repeat 2 s later for " + targets[i].toString());
    }
    return ok;
}

(:test)
function testTargetAlertWithSkippedTicks(logger as Test.Logger) as Boolean {
    // Target 135 (not a multiple of 30): ticks skip 134-136, then 137 is late for the repeat.
    var ticks = [100, 133, 137, 138, 150] as Array<Number>;
    var r = runAlerts(ticks, 135);
    var ok = check(logger, r[0] == 1, "late tick still gives one target alert");
    ok = ok && check(logger, r[1] == 1 && r[2] == 150, "repeat fires once, on the first tick at or after +2 s");
    // Target 120 with the target second skipped.
    var r2 = runAlerts([60, 119, 121, 122, 123, 124] as Array<Number>, 120);
    ok = ok && check(logger, r2[0] == 1 && r2[1] == 1 && r2[2] == 123, "multiple of 30, skipped target tick");
    // No alert before the target.
    var r3 = runAlerts(everySecond(100), 120);
    ok = ok && check(logger, r3[0] == 0 && r3[1] == 0, "nothing before the target");
    // No pulse right after the target alert (it would cut the vibration).
    ok = ok && check(logger, ColdLogic.vibeAt(30, 29) == ColdLogic.VIBE_NONE, "pulse at 30 suppressed after target 29");
    ok = ok && check(logger, ColdLogic.vibeAt(60, 29) == ColdLogic.VIBE_PULSE, "pulses resume later");
    ok = ok && check(logger, ColdLogic.justReached(120, 120) && ColdLogic.justReached(124, 120), "Target! shown for 5 s");
    ok = ok && check(logger, !ColdLogic.justReached(119, 120) && !ColdLogic.justReached(125, 120), "and not outside that window");
    return ok;
}

(:test)
function testElapsedFromMonotonicTimer(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.elapsedSec(1000, 1000) == 0, "zero at start");
    ok = ok && check(logger, ColdLogic.elapsedSec(1000, 3999) == 2, "whole seconds");
    ok = ok && check(logger, ColdLogic.elapsedSec(1000, 121000) == 120, "two minutes");
    ok = ok && check(logger, ColdLogic.elapsedSec(5000, 4000) == 0, "never negative");
    return ok;
}

(:test)
function testCheckpointAndRecoveryCredit(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.checkpointDue(15) && ColdLogic.checkpointDue(45), "due at 15 and 45");
    ok = ok && check(logger, !ColdLogic.checkpointDue(0) && !ColdLogic.checkpointDue(30), "not in a vibration second");
    for (var s = 1; s <= 300; s++) {
        if (ColdLogic.checkpointDue(s) && ColdLogic.vibeAt(s, 120) != ColdLogic.VIBE_NONE) {
            ok = false;
        }
    }
    ok = ok && check(logger, ok, "checkpoint never shares a vibrating second (target 120)");
    var credit = ColdLogic.openCredit([1000, D_MON, 120, 75] as Object?);
    ok = ok && check(logger, credit != null && (credit as Array<Number>)[0] == D_MON, "credits the day");
    ok = ok && check(logger, credit != null && (credit as Array<Number>)[1] == 75, "credits the checkpointed duration");
    ok = ok && check(logger, ColdLogic.openCredit([1000, D_MON, 120, 9] as Object?) == null, "too short is not credited");
    ok = ok && check(logger, ColdLogic.openCredit([1000, D_MON, 120, 10] as Object?) != null, "10 s is credited");
    ok = ok && check(logger, ColdLogic.openCredit(null) == null, "null");
    ok = ok && check(logger, ColdLogic.openCredit([1, 2, 3] as Object?) == null, "wrong size");
    ok = ok && check(logger, ColdLogic.openCredit([1, 2, 3, "x"] as Object?) == null, "wrong type");
    ok = ok && check(logger, ColdLogic.openCredit("open" as Object?) == null, "not an array");
    return ok;
}

(:test)
function testSessionType(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.toggleType(ColdLogic.TYPE_SHOWER) == ColdLogic.TYPE_PLUNGE, "shower to plunge");
    ok = ok && check(logger, ColdLogic.toggleType(ColdLogic.TYPE_PLUNGE) == ColdLogic.TYPE_SHOWER, "plunge to shower");
    ok = ok && check(logger, ColdLogic.validType(1 as Object?) == ColdLogic.TYPE_PLUNGE, "stored plunge");
    ok = ok && check(logger, ColdLogic.validType(0 as Object?) == ColdLogic.TYPE_SHOWER, "stored shower");
    ok = ok && check(logger, ColdLogic.validType(null) == ColdLogic.TYPE_SHOWER, "null gives the default");
    ok = ok && check(logger, ColdLogic.validType(7 as Object?) == ColdLogic.TYPE_SHOWER, "unknown number gives the default");
    ok = ok && check(logger, ColdLogic.validType("plunge" as Object?) == ColdLogic.TYPE_SHOWER, "string gives the default");
    ok = ok && check(logger, ColdLogic.validType([1] as Object?) == ColdLogic.TYPE_SHOWER, "array gives the default");
    ok = ok && check(logger, ColdLogic.typeName(ColdLogic.TYPE_SHOWER).equals("Cold Shower"), "shower name");
    ok = ok && check(logger, ColdLogic.typeName(ColdLogic.TYPE_PLUNGE).equals("Cold Plunge"), "plunge name");
    return ok;
}

(:test)
function testLongPressDecision(logger as Test.Logger) as Boolean {
    var ok = check(logger, !ColdLogic.isLongPress(1000, 1300), "300 ms is a short press");
    ok = ok && check(logger, !ColdLogic.isLongPress(1000, 1699), "699 ms is short");
    ok = ok && check(logger, ColdLogic.isLongPress(1000, 1700), "700 ms is a hold");
    ok = ok && check(logger, ColdLogic.isLongPress(1000, 2500), "1.5 s is a hold");
    ok = ok && check(logger, !ColdLogic.isLongPress(-1, 5000), "unseen press start is not a hold");
    return ok;
}

(:test)
function testActiveTimeAcrossPauses(logger as Test.Logger) as Boolean {
    // Run 1000..4000 ms (3 s), pause, run 9000..12000 ms (3 s), pause, run 20000..20500 ms.
    var acc = 0;
    var ok = check(logger, ColdLogic.activeSec(acc, 1000, 4000, true) == 3, "first run counts while running");
    acc = ColdLogic.activeMs(acc, 1000, 4000, true);
    ok = ok && check(logger, ColdLogic.activeSec(acc, 1000, 9000, false) == 3, "frozen while paused");
    ok = ok && check(logger, ColdLogic.activeSec(acc, 9000, 12000, true) == 6, "resume continues from the frozen time");
    acc = ColdLogic.activeMs(acc, 9000, 12000, true);
    ok = ok && check(logger, acc == 6000, "two runs accumulate");
    ok = ok && check(logger, ColdLogic.activeSec(acc, 20000, 20500, true) == 6, "half a second more is still 6 s");
    ok = ok && check(logger, ColdLogic.activeSec(acc, 20000, 21000, true) == 7, "and 7 s a second later");
    ok = ok && check(logger, ColdLogic.activeSec(0, 5000, 4000, true) == 0, "negative run is clamped");
    return ok;
}

(:test)
function testActiveTimeTimerWrap(logger as Test.Logger) as Boolean {
    // System.getTimer() wraps like int32; the difference of the two readings stays right.
    var start = 2147483000;
    var later = start + 1500;
    var ok = check(logger, ColdLogic.runMs(start, later) == 1500, "run across the wrap point");
    ok = ok && check(logger, ColdLogic.activeSec(2000, start, later, true) == 3, "accumulated plus wrapped run");
    return ok;
}

(:test)
function testShowerScreenTexts(logger as Test.Logger) as Boolean {
    var ok = check(logger, ColdLogic.bigText(0, 120).equals("2:00"), "countdown at the start");
    ok = ok && check(logger, ColdLogic.bigText(119, 120).equals("0:01"), "countdown before the target");
    ok = ok && check(logger, ColdLogic.bigText(120, 120).equals("2:00"), "total at the target");
    ok = ok && check(logger, ColdLogic.bigText(150, 120).equals("2:30"), "total time after the target");
    ok = ok && check(logger, !ColdLogic.targetReached(119, 120) && ColdLogic.targetReached(120, 120), "reached from the target on");
    return ok;
}

(:test)
function testAlertsContinueAfterPause(logger as Test.Logger) as Boolean {
    // Active time simply continues: a reached target does not fire again, a pending one still does.
    var after = ColdLogic.alertStep(121, 122, 120, 0);
    var ok = check(logger, after[0] == ColdLogic.VIBE_NONE, "no second target alert after a resume");
    var before = ColdLogic.alertStep(100, 101, 120, 0);
    ok = ok && check(logger, before[0] == ColdLogic.VIBE_NONE, "nothing yet before the target");
    var hit = ColdLogic.alertStep(119, 120, 120, 0);
    ok = ok && check(logger, hit[0] == ColdLogic.VIBE_TARGET, "target alert still fires after a pause");
    // A pause between the target and its repeat clears the pending repeat (pauseShower resets it).
    var cleared = ColdLogic.alertStep(121, 122, 120, 0);
    ok = ok && check(logger, cleared[0] != ColdLogic.VIBE_REPEAT, "no repeat after a pause");
    return ok;
}

(:test)
function testBreathCue(logger as Test.Logger) as Boolean {
    var start = ColdLogic.breathCue(0);
    var lastIn = ColdLogic.breathCue(3);
    var firstOut = ColdLogic.breathCue(4);
    var lastOut = ColdLogic.breathCue(9);
    var nextIn = ColdLogic.breathCue(10);
    var ok = check(logger, start != null && (start as String).equals("Breathe in"), "starts with in");
    ok = ok && check(logger, lastIn != null && (lastIn as String).equals("Breathe in"), "in lasts 4 s");
    ok = ok && check(logger, firstOut != null && (firstOut as String).equals("Breathe out"), "then out");
    ok = ok && check(logger, lastOut != null && (lastOut as String).equals("Breathe out"), "out lasts 6 s");
    ok = ok && check(logger, nextIn != null && (nextIn as String).equals("Breathe in"), "cycle repeats every 10 s");
    var lastShown = ColdLogic.breathCue(59);
    ok = ok && check(logger, lastShown != null, "shown until 59 s");
    ok = ok && check(logger, ColdLogic.breathCue(60) == null, "gone from 60 s");
    ok = ok && check(logger, ColdLogic.breathCue(-1) == null, "nothing for negative time");
    return ok;
}
