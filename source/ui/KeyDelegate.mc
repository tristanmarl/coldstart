import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Base of every delegate. Actions come ONLY from physical key events (onKey -> onXxxKey).
// Touch must never do anything: wet fingers or water on the screen must not start, stop, save or
// discard a shower. This is an InputDelegate, not a BehaviorDelegate: on a BehaviorDelegate the
// firmware turns taps into onSelect and the buttons into behaviours (onPreviousPage, ...) that never
// reach onKey, so behaviours cannot be used. With an InputDelegate a tap reaches only onTap.
// Subclasses override the onXxxKey methods only.
class KeyDelegate extends WatchUi.InputDelegate {
    // Hold UP. On five-button watches the firmware may report a hold as KEY_MENU; the simulator
    // only reports the release (onKey ACTION) after the press time. So a hold is either KEY_MENU,
    // or a KEY_UP action whose press lasted LONG_PRESS_MS: both call onMenuKey exactly once (a
    // KEY_UP release right after a KEY_MENU is swallowed). A short UP acts on release only.
    private var _upDownAt as Number = -1;
    private var _menuAt as Number = -10000;

    public function initialize() {
        InputDelegate.initialize();
    }

    public function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_UP) {
            _upDownAt = System.getTimer();
        }
        return false;
    }

    // --- Physical keys ------------------------------------------------------------------------

    // One press = one action: DOWN/UP edge events of the same press are ignored, the action
    // event (or an untyped event) dispatches. LIGHT and other keys are left to the firmware.
    public function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        var type = keyEvent.getType();
        var handled = key == WatchUi.KEY_ENTER || key == WatchUi.KEY_ESC ||
            key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN || key == WatchUi.KEY_MENU;
        if (!handled) {
            return false;
        }
        if (type == WatchUi.PRESS_TYPE_DOWN || type == WatchUi.PRESS_TYPE_UP) {
            return true;
        }
        var now = System.getTimer();
        if (key == WatchUi.KEY_UP) {
            var downAt = _upDownAt;
            _upDownAt = -1;
            if (now - _menuAt < 1500) {
                return true;
            }
            if (ColdLogic.isLongPress(downAt, now)) {
                _menuAt = now;
                return onMenuKey();
            }
        } else if (key == WatchUi.KEY_MENU) {
            _menuAt = now;
        }
        if (key == WatchUi.KEY_ENTER) {
            return onStartKey();
        } else if (key == WatchUi.KEY_ESC) {
            return onBackKey();
        } else if (key == WatchUi.KEY_UP) {
            return onUpKey();
        } else if (key == WatchUi.KEY_DOWN) {
            return onDownKey();
        }
        return onMenuKey();
    }

    // Overridable key actions; the default consumes the key and does nothing.
    public function onStartKey() as Boolean {
        return true;
    }

    public function onBackKey() as Boolean {
        return true;
    }

    public function onUpKey() as Boolean {
        return true;
    }

    public function onDownKey() as Boolean {
        return true;
    }

    public function onMenuKey() as Boolean {
        return true;
    }

    // --- Touch ---------------------------------------------------------------------------------

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
