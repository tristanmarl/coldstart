import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Calls every touch callback of a delegate; all must return true (consumed).
function touchConsumed(d as KeyDelegate) as Boolean {
    var t1 = d.onTap(null as WatchUi.ClickEvent) && d.onSwipe(null as WatchUi.SwipeEvent);
    var t2 = d.onFlick(null as WatchUi.FlickEvent) && d.onDrag(null as WatchUi.DragEvent);
    var t3 = d.onHold(null as WatchUi.ClickEvent) && d.onRelease(null as WatchUi.ClickEvent);
    return t1 && t2 && t3;
}

(:test)
function testTouchChangesNothing(logger as Test.Logger) as Boolean {
    var app = getApp();
    var targetBefore = app.target;
    var stateBefore = app.state();
    var ok = check(logger, stateBefore == app.STATE_IDLE, "tests start idle");
    ok = ok && check(logger, touchConsumed(new KeyDelegate()), "base delegate");
    ok = ok && check(logger, touchConsumed(new HomeDelegate(new HomeView())), "home delegate");
    ok = ok && check(logger, touchConsumed(new ShowerDelegate()), "shower delegate");
    ok = ok && check(logger, touchConsumed(new SummaryDelegate()), "summary delegate");
    var view = new ConfirmView(false);
    ok = ok && check(logger, touchConsumed(new ConfirmDelegate(view)), "confirm delegate");
    ok = ok && check(logger, app.target == targetBefore, "target unchanged by touch");
    ok = ok && check(logger, app.state() == stateBefore, "state unchanged by touch");
    ok = ok && check(logger, view.selected == 0, "confirm selection unchanged");
    return ok;
}

// onKey dispatches real key presses to the onXxxKey methods; press/release edges do not.
(:test)
function testOnKeyDispatch(logger as Test.Logger) as Boolean {
    var app = getApp();
    var saved = app.target;
    app.target = 120;
    var home = new HomeDelegate(new HomeView());
    var up = new WatchUi.KeyEvent(WatchUi.KEY_UP, WatchUi.PRESS_TYPE_ACTION);
    var down = new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION);
    var upEdgeDown = new WatchUi.KeyEvent(WatchUi.KEY_UP, WatchUi.PRESS_TYPE_DOWN);
    var upEdgeUp = new WatchUi.KeyEvent(WatchUi.KEY_UP, WatchUi.PRESS_TYPE_UP);
    var ok = check(logger, home.onKey(up) && app.target == 135, "KEY_UP action raises the target");
    ok = ok && check(logger, home.onKey(down) && app.target == 120, "KEY_DOWN action lowers it");
    var edge1 = home.onKey(upEdgeDown);
    var edge2 = home.onKey(upEdgeUp);
    ok = ok && check(logger, edge1 && edge2, "press edges are consumed");
    ok = ok && check(logger, app.target == 120, "press edges do not act");
    var light = new WatchUi.KeyEvent(WatchUi.KEY_LIGHT, WatchUi.PRESS_TYPE_ACTION);
    ok = ok && check(logger, !home.onKey(light), "unhandled keys go to the firmware");
    var view = new ConfirmView(false);
    var confirm = new ConfirmDelegate(view);
    ok = ok && check(logger, confirm.onKey(up) && view.selected == 1, "confirm moves on KEY_UP");
    ok = ok && check(logger, confirm.onKey(down) && view.selected == 0, "and back on KEY_DOWN");
    var base = new KeyDelegate();
    var enter = new WatchUi.KeyEvent(WatchUi.KEY_ENTER, WatchUi.PRESS_TYPE_ACTION);
    var esc = new WatchUi.KeyEvent(WatchUi.KEY_ESC, WatchUi.PRESS_TYPE_ACTION);
    ok = ok && check(logger, base.onKey(enter) && base.onKey(esc), "default START/BACK keys are consumed no-ops");
    app.target = saved;
    ColdStore.saveTarget(saved);
    return ok;
}
