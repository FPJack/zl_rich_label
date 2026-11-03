## 1.0.0

First release, the Flutter version of the iOS library ZLRichLabel 2.3.0.

* `ZLAttributedLabel`: rich text (`ZLAttributedText`) with links, data detectors,
  default / pressed / inactive link styles, padding, vertical alignment, head / middle /
  tail truncation with rich tokens, `adjustsFontSizeToFit`, highlighted text colour and
  per-link accessibility nodes.
* `ZLRichLabel`: regex rules with priorities, handler driven rendering (styles, text
  replacement, inline widgets, taps, long presses, press highlights), render cache,
  expand / collapse tokens, long press / double tap, selection & copy with raw text
  mapping, larger touch areas.
* `ZLTagRichLabel`: `<h>` / `<hN>` tags and generic tags with attributes, nesting,
  self-closing tags and error tolerance; styles, highlights and taps per tag name.
* `ZLTextStyle` chain API, capsule backgrounds (`ZLTextBackground`) and gradient text.
* `ZLRichParser`, `ZLTagParser` and `ZLDataDetector` can be used on their own.
