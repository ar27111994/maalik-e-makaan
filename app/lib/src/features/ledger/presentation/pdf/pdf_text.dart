import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The bundled Latin face (Atkinson Hyperlegible Next), as Flutter's asset
/// bundle keys mm_ui's font.
const latinFontAsset =
    'packages/mm_ui/assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf';

/// Letters of the Arabic script (Urdu), which the pdf package cannot shape.
final RegExp _arabicScript = RegExp(
  r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]',
);

/// Whether [text] has Urdu letters.
bool hasArabicScript(String text) => _arabicScript.hasMatch(text);

/// The light theme's colours, as a printed page uses them.
PdfColor pdfColor(Color color) => PdfColor.fromInt(color.toARGB32());

/// Writes the words of a PDF (receipts, statements) in the app's two faces.
///
/// The pdf package draws text from a font's glyph table without shaping it,
/// which Nastaliq needs: its letters join and stack through the font's
/// substitution and positioning rules. So text with Urdu letters is laid
/// out by Flutter's own text engine (as the app's screens are, with the
/// bundled Noto Nastaliq Urdu, and Atkinson for Latin letters and figures
/// inside it) and placed as an image at print resolution; all other text
/// is PDF text in the bundled Atkinson face, which can be selected and
/// searched.
///
/// Text set apart in Latin letters in an Urdu document (a tenant's name, a
/// reference) is set as the Urdu UI sets it, at the Urdu type's size
/// ([latinScale]), not smaller than the Nastaliq around it. A row's label
/// and value stand on one baseline ([cell], `documentRow`) and a drawn
/// line's letters, not the room drawn around them, line up with the edge
/// of their column.
final class PdfTextWriter {
  new _(this._latin, this.direction, {required this._ascent});

  /// Loads the Latin face from [bundle] for a document written in
  /// [direction].
  static Future<PdfTextWriter> load({
    required ui.TextDirection direction,
    AssetBundle? bundle,
  }) async {
    final data = await (bundle ?? rootBundle).load(latinFontAsset);
    final metrics = TtfParser(data);
    return PdfTextWriter._(
      pw.Font.ttf(data),
      direction,
      ascent: metrics.ascent / metrics.unitsPerEm,
    );
  }

  /// How much larger Latin text is set in an Urdu document: as much as the
  /// Urdu UI's body type is larger than the English UI's, so a name typed
  /// in English is as large beside Nastaliq on paper as on screen.
  static final double urduLatinScale =
      MmTypeScale.urduBody.fontSize! / MmTypeScale.latinBody.fontSize!;

  /// The Latin face's ascent, in ems: where a PDF text's first baseline is.
  final double _ascent;

  /// Device pixels per PDF point of drawn text (about 300 dpi).
  static const double resolution = 300 / 72;

  final pw.Font _latin;

  /// The direction of the document's language.
  final ui.TextDirection direction;

  final _drawn = <String, _Drawn>{};

  bool get rightToLeft => direction == ui.TextDirection.rtl;

  /// How much larger PDF text in Latin letters is set than [text]'s size.
  double get latinScale => rightToLeft ? urduLatinScale : 1;

  /// The page theme: Atkinson for every PDF text.
  pw.ThemeData get theme => pw.ThemeData.withFont(base: _latin, bold: _latin);

  /// [text] at [size] points in [color], at most [maxWidth] points wide,
  /// wrapping, aligned to the start edge (or [end]). With [fill] it takes
  /// the width it is given and sits at that edge of it (a table cell, the
  /// value of a row).
  Future<pw.Widget> text(
    String text, {
    double size = 10,
    PdfColor? color,
    double maxWidth = 480,
    bool bold = false,
    bool end = false,
    bool fill = false,
  }) async => (await cell(
    text,
    size: size,
    color: color,
    maxWidth: maxWidth,
    bold: bold,
    end: end,
    fill: fill,
  )).widget;

  /// [text] as [PdfTextWriter.text] writes it, with where its first
  /// baseline is, in points from its top, so cells side by side can stand
  /// on one baseline ([onBaseline]).
  Future<PdfCell> cell(
    String text, {
    double size = 10,
    PdfColor? color,
    double maxWidth = 480,
    bool bold = false,
    bool end = false,
    bool fill = false,
  }) async {
    final laid = await _text(
      text,
      size: size,
      color: color,
      maxWidth: maxWidth,
      bold: bold,
      end: end,
    );
    if (!fill) return laid;
    return (
      widget: pw.Align(
        alignment: end
            ? pw.AlignmentDirectional.topEnd
            : pw.AlignmentDirectional.topStart,
        child: laid.widget,
      ),
      baseline: laid.baseline,
    );
  }

  /// [cells] each moved down as far as it needs to stand on the lowest
  /// first baseline among them.
  static List<pw.Widget> onBaseline(List<PdfCell> cells) {
    final baseline = cells.map((cell) => cell.baseline).reduce(math.max);
    return [
      for (final cell in cells)
        pw.Padding(
          padding: pw.EdgeInsets.only(top: baseline - cell.baseline),
          child: cell.widget,
        ),
    ];
  }

  Future<PdfCell> _text(
    String text, {
    required double size,
    required PdfColor? color,
    required double maxWidth,
    required bool bold,
    required bool end,
  }) async {
    final ink = color ?? pdfColor(MmColorModes.light.ink);
    final right = end != rightToLeft;
    if (!hasArabicScript(text)) {
      final latin = size * latinScale;
      return (
        widget: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(font: _latin, fontSize: latin, color: ink),
        ),
        baseline: _ascent * latin,
      );
    }
    final key = '$size|${ink.toInt()}|$maxWidth|$bold|$end|$text';
    final drawn = _drawn[key] ??= await _draw(
      text,
      size: size,
      color: ink,
      maxWidth: maxWidth,
      bold: bold,
      end: end,
    );
    return (
      // The room drawn beside the letters (for Nastaliq's strokes) reaches
      // past the column's edge, so the letters line up with it, as PDF
      // text does.
      widget: pw.Transform.translate(
        offset: PdfPoint(right ? drawn.side : -drawn.side, 0),
        child: pw.Image(
          pw.MemoryImage(drawn.png),
          width: drawn.width,
          height: drawn.height,
        ),
      ),
      baseline: drawn.baseline,
    );
  }

  Future<_Drawn> _draw(
    String text, {
    required double size,
    required PdfColor color,
    required double maxWidth,
    required bool bold,
    required bool end,
  }) async {
    final scaled = size * resolution;
    final ink = ui.Color(color.toInt());
    final weight = bold ? ui.FontWeight.w700 : ui.FontWeight.w400;
    final align = (end != rightToLeft) ? ui.TextAlign.right : ui.TextAlign.left;
    ui.Paragraph layout(double width) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textDirection: direction, textAlign: align),
      );
      for (final (run, urdu) in _runs(text)) {
        builder
          ..pushStyle(
            ui.TextStyle(
              color: ink,
              // Latin words among Urdu ones at the Urdu type's size, as
              // the Urdu UI sets them.
              fontSize: urdu ? scaled : scaled * latinScale,
              fontWeight: weight,
              fontVariations: [ui.FontVariation.weight(weight.value * 1.0)],
              fontFamily: urdu
                  ? 'packages/mm_ui/${MmFontFamily.urdu}'
                  : 'packages/mm_ui/${MmFontFamily.latin}',
              height: urdu ? 2 : 1.4,
            ),
          )
          ..addText(run)
          ..pop();
      }
      return builder.build()..layout(ui.ParagraphConstraints(width: width));
    }

    final wide = layout(maxWidth * resolution);
    final paragraph = layout(wide.longestLine.ceilToDouble() + 1);
    // Room for Nastaliq's strokes above and below its lines, and beside
    // them: a line's first letter reaches past the start of its line (a
    // kaf's slanted stroke by about a third of the size), and would
    // otherwise be cut off.
    final margin = (scaled * 0.25).ceilToDouble();
    final side = (scaled * 0.5).ceilToDouble();
    final width = (paragraph.width + 2 * side).ceil();
    final height = (paragraph.height + 2 * margin).ceil();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset(side, margin));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return _Drawn(
      png!.buffer.asUint8List(),
      width: width / resolution,
      height: height / resolution,
      side: side / resolution,
      baseline: (margin + paragraph.alphabeticBaseline) / resolution,
    );
  }

  /// [text] split into runs of Urdu letters and of everything else; the
  /// spaces and punctuation between two Urdu words stay with them.
  static Iterable<(String, bool)> _runs(String text) sync* {
    final buffer = StringBuffer();
    bool? urdu;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isUrdu = hasArabicScript(char);
      final neutral = !isUrdu && !RegExp('[A-Za-z0-9]').hasMatch(char);
      if (urdu == null || neutral || isUrdu == urdu) {
        urdu ??= isUrdu;
        buffer.write(char);
        continue;
      }
      yield (buffer.toString(), urdu);
      buffer
        ..clear()
        ..write(char);
      urdu = isUrdu;
    }
    if (buffer.isNotEmpty) yield (buffer.toString(), urdu ?? false);
  }
}

/// A piece of a document's text, and where its first baseline is, in
/// points from its top.
typedef PdfCell = ({pw.Widget widget, double baseline});

final class _Drawn {
  const new(
    this.png, {
    required this.width,
    required this.height,
    required this.side,
    required this.baseline,
  });

  final Uint8List png;
  final double width;
  final double height;

  /// The room drawn beside the letters at each side, in points.
  final double side;

  /// The first line's baseline, in points from the top.
  final double baseline;
}
