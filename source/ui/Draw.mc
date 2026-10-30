import Toybox.Graphics;
import Toybox.Lang;

// Shared drawing helpers (Dc primitives only, so they work on every target).
module Draw {
    const COLD = 0x33BBFF;
    const OVER = 0xFF8800;
    const DIM = 0x8899AA;

    function clear(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
    }

    // Horizontally centred text; y is the vertical centre.
    function text(dc as Graphics.Dc, str as String, y as Number, font as Graphics.FontType,
                  color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font,
            str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function small(dc as Graphics.Dc) as Graphics.FontType {
        return dc.getHeight() >= 360 ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
    }

    function tiny(dc as Graphics.Dc) as Graphics.FontType {
        return dc.getHeight() >= 360 ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
    }

    // Largest number font whose text fits in 70 % of the width: THAI_HOT where the device has
    // it (AMOLED), else NUMBER_HOT, MEDIUM, and finally the always-present FONT_LARGE.
    function bigFont(dc as Graphics.Dc, str as String) as Graphics.FontType {
        var limit = dc.getWidth() * 70 / 100;
        var candidates = [] as Array<Graphics.FontType>;
        if (Graphics has :FONT_NUMBER_THAI_HOT) {
            candidates.add(Graphics.FONT_NUMBER_THAI_HOT);
        }
        candidates.add(Graphics.FONT_NUMBER_HOT);
        candidates.add(Graphics.FONT_NUMBER_MEDIUM);
        for (var i = 0; i < candidates.size(); i++) {
            if (dc.getTextWidthInPixels(str, candidates[i]) <= limit) {
                return candidates[i];
            }
        }
        return Graphics.FONT_LARGE;
    }

    // Main number, vertically centred at exactly 50 % of the height.
    function big(dc as Graphics.Dc, str as String, color as Number) as Void {
        text(dc, str, dc.getHeight() / 2, bigFont(dc, str), color);
    }
}
