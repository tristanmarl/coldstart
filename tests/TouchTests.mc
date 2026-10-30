import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Calls every behaviour and touch callback of a delegate; all must return true (consumed).
function noBehaviourActs(d as KeyDelegate) as Boolean {
    var a = d.onSelect() && d.onBack() && d.onNextPage();
    var b = d.onPreviousPage() && d.onMenu() && d.onNextMode();
    var c = d.onPreviousMode();
    var first = a && b && c;
    var t1 = d.onTap(null as WatchUi.ClickEvent) && d.onSwipe(null as WatchUi.SwipeEvent);
    var t2 = d.onFlick(null as WatchUi.FlickEvent) && d.onDrag(null as WatchUi.DragEvent);
    var t3 = d.onHold(null as WatchUi.ClickEvent) && d.onRelease(null as WatchUi.ClickEvent);
    var second = t1 && t2 && t3;
    return first && second;
}

(:test)
function testBehavioursAndTouchChangeNothing(logger as Test.Logger) as Boolean {
    var app = getApp();
    var targetBefore = app.target;
    var stateBefore = app.state();
    var ok = check(logger, stateBefore == app.STATE_IDLE, "tests start idle");
    ok = ok && check(logger, noBehaviourActs(new KeyDelegate()), "base delegate");
    ok = ok && check(logger, noBehaviourActs(new HomeDelegate(new HomeView())), "home delegate");
    ok = ok && check(logger, noBehaviourActs(new ShowerDelegate()), "shower delegate");
    ok = ok && check(logger, noBehaviourActs(new SummaryDelegate()), "summary delegate");
    var view = new ConfirmView(false);
    ok = ok && check(logger, noBehaviourActs(new ConfirmDelegate(view)), "confirm delegate");
    ok = ok && check(logger, app.target == targetBefore, "target unchanged by behaviours and touch");
    ok = ok && check(logger, app.state() == stateBefore, "state unchanged by behaviours and touch");
    ok = ok && check(logger, view.selected == 0, "confirm selection unchanged");
    return ok;
}

// The key methods are the only action paths: on Home UP/DOWN move the target by one step.
(:test)
function testKeyMethodsAreTheActionPath(logger as Test.Logger) as Boolean {
    var app = getApp();
    var saved = app.target;
    app.target = 120;
    var home = new HomeDelegate(new HomeView());
    var ok = check(logger, home.onUpKey(), "UP key consumed");
    ok = ok && check(logger, app.target == 135, "UP key raises the target");
    ok = ok && check(logger, home.onDownKey() && app.target == 120, "DOWN key lowers it");
    var view = new ConfirmView(false);
    var confirm = new ConfirmDelegate(view);
    ok = ok && check(logger, confirm.onUpKey() && view.selected == 1, "confirm UP key moves selection");
    ok = ok && check(logger, confirm.onDownKey() && view.selected == 0, "confirm DOWN key moves it back");
    // The default key methods consume and do nothing.
    var base = new KeyDelegate();
    var keys1 = base.onStartKey() && base.onBackKey() && base.onUpKey();
    var keys2 = base.onDownKey() && base.onMenuKey();
    ok = ok && check(logger, keys1 && keys2, "default key methods are consumed no-ops");
    app.target = saved;
    ColdStore.saveTarget(saved);
    return ok;
}
