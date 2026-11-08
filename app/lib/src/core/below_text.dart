import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [child] (a status badge) as an `MmListTile`'s trailing widget that sits
/// under the tile's text, at the end edge, rather than beside its title.
///
/// `MmListTile` puts its trailing widget beside the title whenever the
/// title alone fits beside it, so a short title ("Other") with a longer
/// subtitle leaves the subtitle a column narrower than its words: at 200%
/// text an amount then wraps mid-number ("Rs 1,50" / "0"), and even at
/// 100% an Urdu subtitle runs to five lines. Its reflow does not measure
/// the subtitle (a gap reported to mm_ui: `MmReflow` should count the
/// narrowest width of its `below` line when it decides whether `end` fits).
///
/// Until it does, rows whose subtitle carries amounts and dates (dues,
/// payments, refunds, handovers, who owes what, notifications) hold their
/// badge in this: it tells the tile it is too wide to sit beside any title,
/// so the tile lays it out under the text at its own size, and the
/// subtitle keeps the tile's whole width.
class BelowText extends SingleChildRenderObjectWidget {
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBelowText();
}

class _RenderBelowText extends RenderProxyBox {
  /// Wider than any screen, so the tile never fits it beside the title;
  /// finite, so the tile's own measurements stay finite too.
  static const double _wider = 100000;

  @override
  double computeMaxIntrinsicWidth(double height) => _wider;
}
