import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Persistence in Application.Storage. Every access is guarded: a storage problem must never
// stop a shower from being timed or recorded.
module ColdStore {
    const KEY_TARGET = "target";
    const KEY_STATS = "stats";

    function loadTarget() as Number {
        try {
            var value = Application.Storage.getValue(KEY_TARGET);
            if (value instanceof Number) {
                return ColdLogic.clampTarget(value as Number);
            }
        } catch (error) {
        }
        return ColdLogic.TARGET_DEFAULT;
    }

    function saveTarget(sec as Number) as Void {
        try {
            Application.Storage.setValue(KEY_TARGET, sec);
        } catch (error) {
        }
    }

    function loadStats() as Dictionary {
        try {
            var value = Application.Storage.getValue(KEY_STATS);
            if (ColdLogic.validStats(value as Object?)) {
                return value as Dictionary;
            }
        } catch (error) {
        }
        return ColdLogic.emptyStats();
    }

    function saveStats(stats as Dictionary) as Boolean {
        try {
            Application.Storage.setValue(KEY_STATS, stats);
            return true;
        } catch (error) {
            return false;
        }
    }

    // Local offset from UTC in seconds, derived from the local calendar fields so DST is included.
    function localOffset(now as Time.Moment) as Number {
        try {
            var info = Gregorian.info(now, Time.FORMAT_SHORT);
            var asUtc = Gregorian.moment({:year => info.year, :month => info.month,
                :day => info.day, :hour => info.hour, :minute => info.min, :second => info.sec});
            return asUtc.value() - now.value();
        } catch (error) {
            return 0;
        }
    }

    function today() as Number {
        var now = Time.now();
        return ColdLogic.dayIndex(now.value(), localOffset(now));
    }
}
