import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Material that paints the surface of the widget found by [widget].
Material surfaceOf(WidgetTester tester, Finder widget) => tester.widget(
  find.descendant(of: widget, matching: find.byType(Material)).first,
);

/// The border of the surface of the widget found by [widget].
BorderSide sideOf(WidgetTester tester, Finder widget) =>
    (surfaceOf(tester, widget).shape! as OutlinedBorder).side;
