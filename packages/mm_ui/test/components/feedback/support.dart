import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The colour [icon] is painted in.
Color iconColorOf(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find
          .descendant(of: find.byIcon(icon), matching: find.byType(RichText))
          .first,
    )
    .text
    .style!
    .color!;
