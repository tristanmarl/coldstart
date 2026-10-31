import Toybox.Lang;
import Toybox.WatchUi;

module Navigator {
    function home() as Void {
        var view = new HomeView();
        WatchUi.switchToView(view, new HomeDelegate(view), WatchUi.SLIDE_DOWN);
    }

    function shower() as Void {
        WatchUi.switchToView(new ShowerView(), new ShowerDelegate(), WatchUi.SLIDE_UP);
    }

    function paused() as Void {
        WatchUi.switchToView(new PausedView(), new PausedDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function summary() as Void {
        WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_UP);
    }

    // Key-only choice view; shortShower lists Discard first and "Save anyway" second.
    function confirm(shortShower as Boolean) as Void {
        var view = new ConfirmView(shortShower);
        WatchUi.pushView(view, new ConfirmDelegate(view), WatchUi.SLIDE_UP);
    }
}
