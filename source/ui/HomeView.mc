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

        Draw.text(dc, "Streak " + ColdLogic.currentStreak(stats, today).toString() + " d",
            h * 28 / 100, Draw.small(dc), Graphics.COLOR_WHITE);
        Draw.big(dc, ColdLogic.formatClock(app.target), Draw.COLD);
        var lastSec = stats["lastSec"] as Number;
        Draw.text(dc, lastSec > 0 ? "Last " + ColdLogic.formatClock(lastSec) : "No showers yet",
            h * 70 / 100, Draw.small(dc), lastSec > 0 ? Graphics.COLOR_WHITE : Draw.DIM);
        var notice = app.notice;
        if (notice != null) {
            Draw.text(dc, notice as String, h * 80 / 100, Draw.tiny(dc), Draw.OVER);
        }
        Icons.browseMarkers(dc);
        Icons.startMarker(dc, "play");
    }
}

class HomeDelegate extends KeyDelegate {
    public function initialize(view as HomeView) {
        KeyDelegate.initialize();
    }

    public function onPreviousPage() as Boolean {
        getApp().adjustTarget(1);
        WatchUi.requestUpdate();
        return true;
    }

    public function onNextPage() as Boolean {
        getApp().adjustTarget(-1);
        WatchUi.requestUpdate();
        return true;
    }

    public function onSelect() as Boolean {
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

    // No menu: hold UP does nothing.
    public function onMenu() as Boolean {
        return true;
    }
}
