import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class HomeView extends WatchUi.View {
    public function initialize() {
        View.initialize();
    }

    public function onUpdate(dc as Dc) as Void {
        Draw.clear(dc);
        var app = getApp();
        var h = dc.getHeight();
        var stats = app.stats;
        var today = ColdStore.today();

        Draw.text(dc, ColdLogic.typeName(app.sessionType), h * 17 / 100, Draw.tiny(dc), Draw.COLD);
        Draw.text(dc, "Streak " + ColdLogic.currentStreak(stats, today).toString() + " d",
            h * 28 / 100, Draw.small(dc), Graphics.COLOR_WHITE);
        Draw.big(dc, ColdLogic.formatClock(app.target), Draw.COLD);
        var lastSec = stats["lastSec"] as Number;
        Draw.text(dc, lastSec > 0 ? "Last " + ColdLogic.formatClock(lastSec) : "No sessions yet",
            h * 70 / 100, Draw.small(dc), lastSec > 0 ? Graphics.COLOR_WHITE : Draw.DIM);
        var notice = app.notice;
        if (notice != null) {
            Draw.text(dc, notice as String, h * 80 / 100, Draw.tiny(dc), Draw.OVER);
        }
        Icons.browseMarkers(dc);
        Icons.holdMarker(dc);
        Icons.startMarker(dc, "play");
    }
}

class HomeDelegate extends KeyDelegate {
    public function initialize(view as HomeView) {
        KeyDelegate.initialize();
    }

    public function onUpKey() as Boolean {
        getApp().adjustTarget(1);
        WatchUi.requestUpdate();
        return true;
    }

    public function onDownKey() as Boolean {
        getApp().adjustTarget(-1);
        WatchUi.requestUpdate();
        return true;
    }

    // Hold UP toggles Cold Shower / Cold Plunge (see KeyDelegate for how a hold arrives).
    public function onMenuKey() as Boolean {
        getApp().toggleType();
        WatchUi.requestUpdate();
        return true;
    }

    public function onStartKey() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        if (app.startShower()) {
            Navigator.shower();
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    // BACK exits the app (popping the root view); this is the only way out of Home.
    public function onBackKey() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
