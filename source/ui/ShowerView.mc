import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class ShowerView extends WatchUi.View {
    public function initialize() {
        View.initialize();
    }

    public function onUpdate(dc as Dc) as Void {
        Draw.clear(dc);
        var app = getApp();
        var h = dc.getHeight();
        var w = dc.getWidth();
        var reached = ColdLogic.justReached(app.elapsed, app.target);
        var color = reached ? Draw.DONE : Draw.COLD;

        // Progress arc inside the button-hint ring: clockwise from 12 o'clock, full once the
        // target is reached.
        var radius = (w < h ? w : h) / 2 - dc.getHeight() / 16;
        var fraction = ColdLogic.progress(app.elapsed, app.target);
        dc.setPenWidth(h / 40 + 2);
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w / 2, h / 2, radius);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (fraction >= 1.0) {
            dc.drawCircle(w / 2, h / 2, radius);
        } else if (fraction > 0.0) {
            var end = (90.0 - 360.0 * fraction).toNumber();
            dc.drawArc(w / 2, h / 2, radius, Graphics.ARC_CLOCKWISE, 90, end);
        }
        dc.setPenWidth(1);

        // Top line: the target, always visible (green for 5 s after reaching it).
        Draw.text(dc, "Target " + ColdLogic.formatClock(app.target), h * 28 / 100, Draw.small(dc),
            reached ? Draw.DONE : Draw.DIM);
        // Big number: countdown before the target, total time from the target on.
        Draw.big(dc, ColdLogic.bigText(app.elapsed, app.target), color);
        Draw.heartRate(dc, app.hrNow, h * 79 / 100);
        Icons.startMarker(dc, "pause");
    }
}

// Paused: frozen total time, START resumes, BACK finishes.
class PausedView extends WatchUi.View {
    public function initialize() {
        View.initialize();
    }

    public function onUpdate(dc as Dc) as Void {
        Draw.clear(dc);
        var app = getApp();
        var h = dc.getHeight();
        Draw.text(dc, "Paused", h * 28 / 100, Draw.small(dc), Draw.OVER);
        Draw.big(dc, ColdLogic.formatClock(app.elapsed), Graphics.COLOR_WHITE);
        Draw.text(dc, "Target " + ColdLogic.formatClock(app.target), h * 68 / 100, Draw.small(dc),
            Draw.DIM);
        Icons.startMarker(dc, "play");
        Icons.backMarker(dc, "stop");
    }
}

class PausedDelegate extends KeyDelegate {
    public function initialize() {
        KeyDelegate.initialize();
    }

    public function onStartKey() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        if (app.resumeShower()) {
            Navigator.shower();
        }
        return true;
    }

    public function onBackKey() as Boolean {
        getApp().finishShower();
        Navigator.summary();
        return true;
    }
}

class ShowerDelegate extends KeyDelegate {
    public function initialize() {
        KeyDelegate.initialize();
    }

    public function onStartKey() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        if (app.pauseShower()) {
            Navigator.paused();
        }
        return true;
    }

    // Never leave silently while recording.
    public function onBackKey() as Boolean {
        return true;
    }
}
