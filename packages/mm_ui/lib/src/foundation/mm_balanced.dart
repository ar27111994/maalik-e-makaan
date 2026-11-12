import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out a paragraph ([child], a text widget) as narrow as it can be
/// without taking another line, so a centred paragraph's lines come out
/// even and the last one never holds a single word under the others: a
/// balanced line break, as CSS's `text-wrap: balance` gives.
///
/// A paragraph that fits on one line keeps its own width. The widest word
/// of a paragraph sets how narrow it can go.
///
/// Internal to mm_ui: any component family may use it.
class MmBalanced extends SingleChildRenderObjectWidget {
  /// Balances the lines of [child].
  const new({required Widget super.child, super.key});

  @override
  RenderMmBalanced createRenderObject(BuildContext context) =>
      RenderMmBalanced();
}

/// The render object of [MmBalanced]; it always has a child.
class RenderMmBalanced extends RenderProxyBox {
  /// How close the search for the narrowest width comes, in logical
  /// pixels.
  static const double _precision = 0.5;

  /// The constraints [constraints] narrowed to the balanced width.
  BoxConstraints _balanced(BoxConstraints constraints) {
    final child = this.child!;
    final widest = constraints.maxWidth;
    if (!widest.isFinite ||
        child.getMaxIntrinsicWidth(double.infinity) <= widest) {
      return constraints;
    }
    final loose = constraints.loosen();
    double heightAt(double width) =>
        child.getDryLayout(loose.copyWith(maxWidth: width)).height;
    final lines = heightAt(widest);
    // The narrowest width with as many lines: never narrower than the
    // widest word, which would break inside it.
    var low = child.getMinIntrinsicWidth(double.infinity);
    var high = widest;
    if (low >= high) return constraints;
    while (high - low > _precision) {
      final middle = (low + high) / 2;
      if (heightAt(middle) > lines) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return constraints.copyWith(
      minWidth: constraints.minWidth > high ? high : constraints.minWidth,
      maxWidth: high,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child!.getDryLayout(_balanced(constraints));

  @override
  void performLayout() {
    final child = this.child!
      ..layout(_balanced(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}
