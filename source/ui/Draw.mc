import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Shared drawing helpers (Dc primitives only, so they work on every target).
module Draw {
    const COLD = 0x33BBFF;
    const OVER = 0xFF8800;
    const DIM = 0x8899AA;
    const DONE = 0x22DD77;

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

    // Text centred on x (columns).
    function textAt(dc as Graphics.Dc, str as String, x as Number, y as Number,
                    font as Graphics.FontType, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // Filled heart from two circles and a triangle; r is the circle radius.
    function heart(dc as Graphics.Dc, cx as Number, cy as Number, r as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r, cy - r / 2, r);
        dc.fillCircle(cx + r, cy - r / 2, r);
        dc.fillPolygon([[cx - r * 2, cy - r / 4], [cx + r * 2, cy - r / 4], [cx, cy + r * 5 / 2]]);
    }

    // Heart-rate readout: heart icon left of a large number ("--" when none), centred at y.
    // ringRadius is the inner edge of the circle it sits in: the largest number font whose row
    // fits inside that circle at the glyphs' lower edge is used, so three digits never cross it.
    function heartRate(dc as Graphics.Dc, hr as Number, y as Number, ringRadius as Number) as Void {
        var h = dc.getHeight();
        var str = hr > 0 ? hr.toString() : "--";
        var r = h / 40 + 1;
        var gap = r;
        var fonts = hr > 0 ?
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE,
             Graphics.FONT_MEDIUM] as Array<Graphics.FontType> :
            [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>;
        var font = fonts[fonts.size() - 1];
        var tw = 0;
        var total = 0;
        for (var i = 0; i < fonts.size(); i++) {
            font = fonts[i];
            tw = dc.getTextWidthInPixels(str, font);
            total = r * 4 + gap + tw;
            if (total <= rowWidth(dc, y, dc.getFontHeight(font) / 3, ringRadius)) {
                break;
            }
        }
        var left = dc.getWidth() / 2 - total / 2;
        heart(dc, left + r * 2, y, r, 0xFF3355);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + r * 4 + gap, y, font, str,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Usable width of a row centred at y whose glyphs reach `half` pixels below y, inside a
    // circle of the given radius around the screen centre (with a small margin).
    function rowWidth(dc as Graphics.Dc, y as Number, half as Number, radius as Number) as Number {
        var dy = (y - dc.getHeight() / 2).abs() + half;
        var inner = radius - dc.getHeight() / 30;
        if (dy >= inner) {
            return 0;
        }
        return (2.0 * Math.sqrt((inner * inner - dy * dy).toFloat())).toNumber();
    }
}
