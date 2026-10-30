import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SummaryView extends WatchUi.View {
    public function initialize() {
        View.initialize();
    }

    public function onUpdate(dc as Dc) as Void {
        Draw.clear(dc);
        var app = getApp();
        var h = dc.getHeight();
        var tooShort = app.elapsed < ColdLogic.MIN_SAVE_SEC;
        var hit = app.elapsed >= app.target;
        Draw.text(dc, tooShort ? "Too short" : (hit ? "Target hit" : "Target missed"),
            h * 28 / 100, Draw.small(dc), tooShort || !hit ? Draw.OVER : Draw.COLD);
        Draw.big(dc, ColdLogic.formatClock(app.elapsed), Graphics.COLOR_WHITE);
        var line = ColdLogic.hrLine(app.hrMin(), app.hrAverage(), app.hrMax());
        if (line != null) {
            Draw.text(dc, line as String, h * 70 / 100, Draw.small(dc), Graphics.COLOR_WHITE);
        }
        Icons.startMarker(dc, "check");
        Icons.backMarker(dc, "cross");
    }
}

class SummaryDelegate extends KeyDelegate {
    public function initialize() {
        KeyDelegate.initialize();
    }

    public function onSelect() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        if (app.elapsed < ColdLogic.MIN_SAVE_SEC) {
            Navigator.confirm(true);
        } else if (app.saveShower()) {
            Navigator.home();
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    public function onBack() as Boolean {
        Navigator.confirm(false);
        return true;
    }

    public function onMenu() as Boolean {
        Navigator.confirm(false);
        return true;
    }
}

// Key-only save/discard choice (no Menu2: menus accept taps). UP/DOWN move, START confirms,
// BACK cancels. Short showers list Discard first, others list Keep first.
class ConfirmView extends WatchUi.View {
    public var selected as Number = 0;
    public var shortShower as Boolean;

    public function initialize(isShort as Boolean) {
        View.initialize();
        shortShower = isShort;
    }

    public function labels() as Array<String> {
        return shortShower ? ["Discard", "Save anyway"] as Array<String> :
            ["Keep", "Discard"] as Array<String>;
    }

    public function onUpdate(dc as Dc) as Void {
        Draw.clear(dc);
        var h = dc.getHeight();
        Draw.text(dc, shortShower ? "Too short" : "Discard shower?", h * 22 / 100, Draw.small(dc),
            Draw.OVER);
        var items = labels();
        for (var i = 0; i < items.size(); i++) {
            var active = i == selected;
            Draw.text(dc, (active ? "> " : "  ") + items[i], h * (46 + 16 * i) / 100,
                Draw.small(dc), active ? Draw.COLD : Draw.DIM);
        }
        Draw.text(dc, "START: choose · BACK: cancel", h * 88 / 100, Draw.tiny(dc), Draw.DIM);
    }
}

class ConfirmDelegate extends KeyDelegate {
    private var _view as ConfirmView;

    public function initialize(view as ConfirmView) {
        KeyDelegate.initialize();
        _view = view;
    }

    public function onPreviousPage() as Boolean {
        _view.selected = (_view.selected + 1) % 2;
        WatchUi.requestUpdate();
        return true;
    }

    public function onNextPage() as Boolean {
        _view.selected = (_view.selected + 1) % 2;
        WatchUi.requestUpdate();
        return true;
    }

    public function onSelect() as Boolean {
        var app = getApp();
        if (!app.acceptStart()) {
            return true;
        }
        var discard = _view.shortShower ? _view.selected == 0 : _view.selected == 1;
        var save = _view.shortShower && _view.selected == 1;
        if (!discard && !save) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (discard ? app.discardShower() : app.saveShower()) {
            Navigator.home();
        }
        return true;
    }

    public function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
