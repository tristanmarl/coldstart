import Toybox.Lang;
import Toybox.WatchUi;

// Base of every delegate: touch is ignored everywhere (wet fingers or water on the screen must
// never start, stop, save or discard a shower). Each touch callback is consumed so the firmware
// does not map it to onSelect/onBack/onNextPage. Actions come from the physical keys only.
class KeyDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    public function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }

    public function onFlick(flickEvent as WatchUi.FlickEvent) as Boolean {
        return true;
    }

    public function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        return true;
    }

    public function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    public function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }
}
