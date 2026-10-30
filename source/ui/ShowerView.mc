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
        var over = ColdLogic.isOvertime(app.elapsed, app.target);
        var color = over ? Draw.OVER : Draw.COLD;

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

        Draw.text(dc, over ? "Overtime" : "Target " + ColdLogic.formatClock(app.target),
            h * 28 / 100, Draw.small(dc), Draw.DIM);
        Draw.big(dc, ColdLogic.countdownText(app.elapsed, app.target), color);
        var hr = app.hrNow > 0 ? "HR " + app.hrNow.toString() : "HR --";
        Draw.text(dc, hr, h * 70 / 100, Draw.small(dc), Graphics.COLOR_WHITE);
        Icons.startMarker(dc, "stop");
    }
}

class ShowerDelegate extends KeyDelegate {
    public function initialize() {
        KeyDelegate.initialize();
    }

    public function onSelect() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        app.stopShower();
        Navigator.summary();
        return true;
    }

    // Never leave silently while recording.
    public function onBack() as Boolean {
        return true;
    }
}
