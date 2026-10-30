import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Every touch callback of every delegate must return true (consumed). A consumed touch event
// cannot reach the BehaviorDelegate mapping to onSelect/onBack/onNextPage.
function touchConsumed(d as KeyDelegate) as Boolean {
    var a = d.onTap(null as WatchUi.ClickEvent);
    var b = d.onSwipe(null as WatchUi.SwipeEvent);
    var c = d.onFlick(null as WatchUi.FlickEvent);
    var e = d.onDrag(null as WatchUi.DragEvent);
    var f = d.onHold(null as WatchUi.ClickEvent);
    var g = d.onRelease(null as WatchUi.ClickEvent);
    var first = a && b && c;
    var second = e && f && g;
    return first && second;
}

(:test)
function testTouchIgnoredByAllDelegates(logger as Test.Logger) as Boolean {
    var ok = check(logger, touchConsumed(new KeyDelegate()), "base delegate");
    ok = ok && check(logger, touchConsumed(new HomeDelegate(new HomeView())), "home delegate");
    ok = ok && check(logger, touchConsumed(new ShowerDelegate()), "shower delegate");
    ok = ok && check(logger, touchConsumed(new SummaryDelegate()), "summary delegate");
    var view = new ConfirmView(false);
    ok = ok && check(logger, touchConsumed(new ConfirmDelegate(view)), "confirm delegate");
    ok = ok && check(logger, view.selected == 0, "touch does not move the confirm selection");
    return ok;
}
