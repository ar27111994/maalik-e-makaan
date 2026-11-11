import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/application/documents.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _asAccountant = PortfolioMembership(
  id: '0192d0c4-0000-7000-8000-000000000001',
  name: 'Gulberg Houses',
  role: MemberRole.accountant,
);

TestApp _as(PortfolioMembership membership) =>
    TestApp(portfolios: [membership, plaza]);

Widget _tenant() => MmPage(
  title: 'Ali Raza',
  body: DocumentsSection(
    owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
  ),
);

Widget _archivedUnit() => MmPage(
  title: 'Ground floor',
  body: DocumentsSection(
    owner: (entity: DocumentEntity.unit, id: groundFloor.id),
    canAdd: false,
  ),
);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byWidgetPredicate((widget) => widget is Dialog),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is MmTextField && widget.label == label,
  ),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  final target = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == field,
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option, findRichText: true).last);
  await tester.pumpAndSettle();
}

/// Closes the sheet on top, as its close button does.
Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close').last);
  await tester.pumpAndSettle();
}

List<String> _called(TestApp app) => [
  for (final call in app.documents.calls) call.$1,
];

void main() {
  group('the list', () {
    testWidgets("shows a record's documents, newest first", (tester) async {
      await pumpScreen(tester, _tenant);
      expect(find.text('Documents'), findsOneWidget);
      expect(
        find.text("Photos and PDFs, seen only by this portfolio's team."),
        findsOneWidget,
      );
      final front = tester.getTopLeft(find.text('CNIC front'));
      final back = tester.getTopLeft(find.text('CNIC back'));
      expect(front.dy, lessThan(back.dy));
      // The kind, the day and the format; the size is on the sheet.
      expect(find.text('CNIC, front · 1 Nov 2026 · JPEG'), findsOneWidget);
      expect(find.text('Add document'), findsOneWidget);
    });

    testWidgets('a photo shows small; one that cannot be drawn its icon', (
      tester,
    ) async {
      final app = TestApp();
      app.documents.thumbnails = {
        cnicFrontScan.id: Uri.parse('https://files.example/front.jpg?token=t'),
      };
      await pumpScreen(tester, _tenant, app: app);
      // One request for the page's links.
      expect(
        app.documents.calls.where((c) => c.$1 == 'thumbnailLinks'),
        isNotEmpty,
      );
      final image = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            ((widget.image as ResizeImage).imageProvider as ThumbnailImage)
                    .link ==
                Uri.parse('https://files.example/front.jpg?token=t'),
      );
      expect(image, findsOneWidget);
      expect(tester.getSize(image), const Size.square(MmSize.avatar));
      // The test's network answers 400: the row keeps its icon.
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: image, matching: find.byIcon(MmIcons.image)),
        findsOneWidget,
      );
    });

    testWidgets('photo links are signed again before they expire, and a '
        'photo is kept by its document, not its link', (tester) async {
      final app = TestApp();
      app.documents.thumbnails = {
        cnicFrontScan.id: Uri.parse('https://files.example/front.jpg?token=1'),
      };
      await pumpScreen(tester, _tenant, app: app);
      int signings() =>
          _called(app).where((call) => call == 'thumbnailLinks').length;
      ThumbnailImage shown() =>
          (tester
                          .widget<Image>(
                            find.byWidgetPredicate(
                              (widget) =>
                                  widget is Image &&
                                  widget.image is ResizeImage &&
                                  (widget.image as ResizeImage).imageProvider
                                      is ThumbnailImage,
                            ),
                          )
                          .image
                      as ResizeImage)
                  .imageProvider
              as ThumbnailImage;
      expect(signings(), 1);
      final first = shown();
      // Before the five minutes a link works for are up, it is signed
      // again, so a row built later still finds a working one.
      app.documents.thumbnails = {
        cnicFrontScan.id: Uri.parse('https://files.example/front.jpg?token=2'),
      };
      await tester.pump(linksRenewedAfter);
      await tester.pump();
      expect(signings(), 2);
      final renewed = shown();
      expect(renewed.link.queryParameters['token'], '2');
      // The same image to the cache and to the row: not fetched again.
      expect(renewed, first);
      expect(renewed.hashCode, first.hashCode);
      // A link not yet that old is not signed again.
      await tester.pump(const Duration(minutes: 1));
      expect(signings(), 2);
    });

    testWidgets('a name that is its kind is not repeated', (tester) async {
      final app = TestApp();
      app.documents.documentsOf(cnicFrontScan.owner)
        ..clear()
        ..add(cnicFrontScan.copyWith(fileName: 'CNIC, front'));
      await pumpScreen(tester, _tenant, app: app);
      expect(find.text('1 Nov 2026 · JPEG'), findsOneWidget);
    });

    testWidgets('an empty record says so; adding can be turned off', (
      tester,
    ) async {
      await pumpScreen(tester, _archivedUnit);
      expect(find.text('No documents yet.'), findsOneWidget);
      expect(find.text('Add document'), findsNothing);
    });

    testWidgets('an empty record says what to add to it', (tester) async {
      Widget section(DocumentEntity entity) => MmPage(
        title: 'Record',
        body: DocumentsSection(owner: (entity: entity, id: 'empty')),
      );
      for (final (entity, empty) in [
        (
          DocumentEntity.tenant,
          'No documents yet. Add photos of the CNIC, front and back.',
        ),
        (
          DocumentEntity.lease,
          'No documents yet. Add the signed agreement and the police '
              'registration.',
        ),
        (
          DocumentEntity.unit,
          'No documents yet. Add photos of the unit and its meters.',
        ),
        (
          DocumentEntity.property,
          'No documents yet. Add the property papers and photos.',
        ),
        for (final entity in const [
          DocumentEntity.payment,
          DocumentEntity.expense,
          DocumentEntity.maintenanceRequest,
          DocumentEntity.utilityBill,
          DocumentEntity.meterReading,
        ])
          (entity, 'No documents yet.'),
      ]) {
        await pumpScreen(tester, () => section(entity));
        expect(find.text(empty), findsOneWidget, reason: entity.name);
      }
      // A member who cannot add any is not told to.
      await pumpScreen(
        tester,
        () => section(DocumentEntity.tenant),
        app: _as(gulbergAsViewer),
      );
      expect(find.text('No documents yet.'), findsOneWidget);
    });

    testWidgets('pages read more', (tester) async {
      final app = TestApp()..documents.pageLimit = 1;
      await pumpScreen(tester, _tenant, app: app);
      expect(find.text('CNIC back'), findsNothing);
      await _tap(tester, 'Show more');
      expect(find.text('CNIC back'), findsOneWidget);
    });

    testWidgets('a list that cannot load says so and retries', (tester) async {
      final app = TestApp()..documents.readFailure = const Forbidden();
      await pumpScreen(tester, _tenant, app: app);
      expect(find.text('Documents could not be loaded'), findsOneWidget);
      app.documents.readFailure = null;
      await _tap(tester, 'Try again');
      expect(find.text('CNIC front'), findsOneWidget);
    });

    testWidgets('nothing shows before the portfolio is known', (tester) async {
      await pumpScreen(tester, _tenant, app: TestApp(portfolios: const []));
      expect(find.text('Documents'), findsNothing);
    });
  });

  group('a document', () {
    testWidgets('opens and downloads through short-lived links', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'CNIC front');
      // The sheet's title is the name, the landlord's text, set in its own
      // script's face (MmSheet's userTitle).
      expect(find.text('Document'), findsNothing);
      expect(find.text('CNIC front'), findsNWidgets(2));
      expect(find.text('CNIC, front'), findsOneWidget);
      expect(find.text('JPEG photo, 240\u00a0KB'), findsOneWidget);
      expect(shown('1 Nov 2026, 11:30'), findsOneWidget);
      expect(shown('minutes'), findsNothing);
      await _tap(tester, 'Open');
      await _tap(tester, 'Download');
      expect(app.opened, [
        Uri.parse('https://files.example/${cnicFrontScan.storagePath}?token=t'),
        Uri.parse(
          'https://files.example/${cnicFrontScan.storagePath}'
          '?token=t&download=CNIC+front',
        ),
      ]);
      // One link for both: made when the sheet opened.
      expect(_called(app).where((c) => c == 'links'), hasLength(1));
      app.canOpenLinks = false;
      await _tap(tester, 'Open');
      expect(find.text('The link could not be opened.'), findsOneWidget);
    });

    testWidgets('a link that cannot be made says so; Open tries again', (
      tester,
    ) async {
      final app = TestApp()..documents.linkFailure = const NetworkFailure();
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'CNIC front');
      expect(
        find.textContaining('No connection', findRichText: true),
        findsOneWidget,
      );
      app.documents.linkFailure = null;
      await _tap(tester, 'Open');
      expect(app.opened, hasLength(1));
      app.documents.linkFailure = const NotFoundFailure();
      await _close(tester);
      await _tap(tester, 'CNIC front');
      app.documents.linkFailure = const NotFoundFailure();
      await _tap(tester, 'Download');
      expect(app.opened, hasLength(1));
    });

    testWidgets('is renamed and its kind changed', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'CNIC front');
      await _tap(tester, 'Rename or change kind');
      await _tap(tester, 'Cancel');
      expect(find.text('Open'), findsOneWidget);
      await _tap(tester, 'Rename or change kind');
      await _type(tester, 'Name', '   ');
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _type(tester, 'Name', 'Front side');
      await _choose(tester, 'Kind', 'CNIC, back');
      app.documents.gate.failure = const Forbidden();
      await _tap(tester, 'Save');
      expect(
        find.textContaining('You do not have permission', findRichText: true),
        findsOneWidget,
      );
      app.documents.gate.failure = null;
      await _tap(tester, 'Save');
      expect(find.text('Front side saved.'), findsOneWidget);
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'updateDocument').$2,
        [cnicFrontScan.id, 'Front side', DocumentKind.cnicBack],
      );
      expect(find.text('Front side'), findsOneWidget);
    });

    testWidgets('is deleted after confirming', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'CNIC front');
      await _tap(tester, 'Delete');
      expect(find.text('Delete CNIC front?'), findsOneWidget);
      await _confirm(tester, 'Cancel');
      expect(_called(app), isNot(contains('deleteDocument')));
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(find.text('CNIC front deleted.'), findsOneWidget);
      expect(find.text('CNIC front'), findsNothing);
      expect(find.text('CNIC back'), findsOneWidget);
    });

    testWidgets('a refused delete stays open and says why', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'CNIC front');
      app.documents.gate.failure = const Forbidden();
      await _tap(tester, 'Delete');
      await _confirm(tester, 'Delete');
      expect(
        find.textContaining('You do not have permission', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('viewers open documents and add nothing', (tester) async {
      await pumpScreen(tester, _tenant, app: _as(gulbergAsViewer));
      expect(find.text('Add document'), findsNothing);
      await _tap(tester, 'CNIC front');
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Rename or change kind'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('accountants rename but do not delete', (tester) async {
      await pumpScreen(tester, _tenant, app: _as(_asAccountant));
      expect(find.text('Add document'), findsOneWidget);
      await _tap(tester, 'CNIC front');
      expect(find.text('Rename or change kind'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });
  });

  group('adding a document', () {
    testWidgets('a photo is taken, made smaller and uploaded', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'Add document');
      expect(
        find.text(
          'Add a photo, or a PDF of up to 10 MB. Photos are made smaller '
          'first.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Take a photo');
      expect(app.picker.calls, ['takePhoto']);
      expect(find.text('JPEG photo'), findsOneWidget);
      // How much smaller, not the size again.
      expect(
        find.text('Made smaller from 2.4\u00a0MB to 286\u00a0KB.'),
        findsOneWidget,
      );
      // The photo itself, to check before it is uploaded.
      final preview = tester.widget<Image>(find.byType(Image));
      expect((preview.image as MemoryImage).bytes, same(preparedPhoto));
      expect(preview.semanticLabel, 'Preview of the photo');
      // A camera photo is named after its kind.
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        isEmpty,
      );
      await _tap(tester, 'Upload');
      expect(find.text('CNIC, front added.'), findsOneWidget);
      expect(find.text('Upload'), findsNothing);
      final record = app.documents.calls.lastWhere(
        (c) => c.$1 == 'recordDocument',
      );
      expect(record.$2.skip(1), ['CNIC, front', DocumentKind.cnicFront]);
      expect(
        record.$2.first,
        startsWith('${gulberg.id}/tenant/${aliRaza.id}/'),
      );
      expect(record.$2.first, endsWith('.jpg'));
    });

    testWidgets('a file keeps its name; the kind is chosen', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('2\u00a0KB'), findsOneWidget);
      // A PDF shows its icon, not a preview.
      expect(find.byType(Image), findsNothing);
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        'Agreement scan',
      );
      await _choose(tester, 'Kind', 'Police registration');
      await _type(tester, 'Name', 'Thana slip');
      await _tap(tester, 'Upload');
      expect(find.text('Thana slip added.'), findsOneWidget);
      expect(
        app.documents.calls
            .lastWhere((c) => c.$1 == 'recordDocument')
            .$2
            .skip(1),
        ['Thana slip', DocumentKind.policeRegistration],
      );
    });

    testWidgets('cancelling a pick changes nothing', (tester) async {
      final app = TestApp()
        ..picker.photo = null
        ..picker.file = null;
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Take a photo');
      await _tap(tester, 'Choose a file');
      expect(find.text('Upload'), findsNothing);
      expect(find.text('Take a photo'), findsOneWidget);
    });

    testWidgets('a refused pick or file says why', (tester) async {
      final app = TestApp()
        ..picker.failure = const RejectedFailure('picker_access_denied');
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Take a photo');
      expect(
        find.text(
          'Maalik-e-Makaan may not use the camera or your files. Allow it '
          "in your phone's settings.",
        ),
        findsOneWidget,
      );
      app.picker
        ..failure = null
        ..file = ChosenFileFor.gif;
      await _tap(tester, 'Choose a file');
      expect(
        find.text(
          'Only photos (JPEG, PNG, WebP or HEIC) and PDFs can be added.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking shows progress until the file is ready', (
      tester,
    ) async {
      final app = TestApp();
      app.picker.gate.close();
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await tester.tap(find.text('Choose a file'));
      await tester.pump();
      expect(
        tester
            .widgetList<MmButton>(find.byType(MmButton))
            .where((b) => b.busy)
            .map((b) => b.label),
        ['Choose a file'],
      );
      expect(find.bySemanticsLabel('Getting the file ready'), findsOneWidget);
      app.picker.gate.open();
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets('a failed upload is tried again without a second file', (
      tester,
    ) async {
      final app = TestApp();
      app.documents.recordFailures.add(const NetworkFailure());
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      await _tap(tester, 'Upload');
      expect(
        find.textContaining('No connection', findRichText: true),
        findsOneWidget,
      );
      await _tap(tester, 'Upload');
      expect(find.text('Agreement scan added.'), findsOneWidget);
      expect(_called(app).where((c) => c == 'uploadFile'), hasLength(1));
      expect(_called(app), isNot(contains('discardFile')));
    });

    testWidgets('giving up deletes the file stored without a row', (
      tester,
    ) async {
      final app = TestApp();
      app.documents.recordFailures.addAll(const [
        NetworkFailure(),
        NetworkFailure(),
      ]);
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      await _tap(tester, 'Upload');
      final first = app.documents.calls
          .lastWhere((c) => c.$1 == 'uploadFile')
          .$2
          .single;
      // Another file: the first one's upload is given up.
      await _tap(tester, 'Choose another file');
      expect(find.text('Take a photo'), findsOneWidget);
      expect(app.documents.calls.last.$1, 'discardFile');
      expect(app.documents.calls.last.$2, [first]);
      await _tap(tester, 'Take a photo');
      await _tap(tester, 'Upload');
      final second = app.documents.calls
          .lastWhere((c) => c.$1 == 'uploadFile')
          .$2
          .single;
      await _close(tester);
      expect(app.documents.calls.last.$1, 'discardFile');
      expect(app.documents.calls.last.$2, [second]);
      expect(app.documents.stored, isNot(contains(second)));
    });

    testWidgets('closing while an upload runs lets it finish', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      app.documents.gate.close();
      await tester.tap(find.text('Upload'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close').last);
      await tester.pump();
      app.documents.gate.open();
      await tester.pumpAndSettle();
      expect(_called(app), isNot(contains('discardFile')));
      expect(find.text('Agreement scan'), findsOneWidget);
    });

    testWidgets('accountants leave a stranded file to the daily sweep', (
      tester,
    ) async {
      final app = _as(_asAccountant);
      app.documents.recordFailures.add(const NetworkFailure());
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      await _tap(tester, 'Upload');
      await _close(tester);
      expect(_called(app), isNot(contains('discardFile')));
    });
  });

  group('a photo Android lost', () {
    const recoveredNotice =
        'The app closed while the camera was open, but your photo was kept. '
        'Check it, then upload it.';
    final tenantList = (
      portfolioId: gulberg.id,
      owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
    );

    LostPhotoController lost(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(lostPhotoProvider.notifier);

    String? kept(TestApp app) =>
        app.settings.values[AppSettings.cameraTargetKey] as String?;

    testWidgets('the record is remembered while the camera is open, and '
        'forgotten when it answers', (tester) async {
      final app = TestApp();
      app.picker.gate.close();
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await tester.tap(find.text('Take a photo'));
      await tester.pump();
      final target = CameraTarget.tryParse(kept(app)!)!;
      expect(target.userId, testUserId);
      expect(target.portfolioId, gulberg.id);
      expect(target.owner, tenantList.owner);
      // The screen the sheet is over, to come back to.
      expect(target.location, screenPath);
      expect(
        DateTime.now().difference(target.openedAt),
        lessThan(const Duration(minutes: 1)),
      );
      // A photo.
      app.picker.gate.open();
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsOneWidget);
      expect(kept(app), isNull);
      // No photo.
      await _tap(tester, 'Choose another file');
      app.picker.photo = null;
      await _tap(tester, 'Take a photo');
      expect(kept(app), isNull);
      // A refusal.
      app.picker.failure = const RejectedFailure('picker_access_denied');
      await _tap(tester, 'Take a photo');
      expect(kept(app), isNull);
      // A camera photo is never one that came back.
      expect(find.text(recoveredNotice), findsNothing);
    });

    testWidgets('iOS and the web remember nothing: they never lose a photo', (
      tester,
    ) async {
      final app = TestApp();
      app.picker.gate.close();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpScreen(tester, _tenant, app: app);
        await _tap(tester, 'Add document');
        await tester.tap(find.text('Take a photo'));
        await tester.pump();
        // The camera is open, and the device keeps nothing.
        expect(app.picker.calls, ['takePhoto']);
        expect(
          app.settings.values,
          isNot(contains(AppSettings.cameraTargetKey)),
        );
        app.picker.gate.open();
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(find.text('Upload'), findsOneWidget);
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    testWidgets('a device that cannot remember still takes photos', (
      tester,
    ) async {
      final app = TestApp()..settings.writeFailure = Exception('read-only');
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Take a photo');
      expect(app.picker.calls, ['takePhoto']);
      expect(find.text('Upload'), findsOneWidget);
      expect(kept(app), isNull);
      // Remembered, but not forgotten: the next camera's target replaces
      // it.
      app
        ..settings.writeFailure = null
        ..picker.gate.close();
      await _tap(tester, 'Choose another file');
      await tester.tap(find.text('Take a photo'));
      await tester.pump();
      expect(kept(app), isNotNull);
      app.settings.writeFailure = Exception('read-only');
      app.picker.gate.open();
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsOneWidget);
      expect(kept(app), isNotNull);
    });

    testWidgets('one that came back opens in the add sheet, made ready, and '
        'goes up only when the landlord says', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      final photo = app.picker.photo!;
      lost(tester).hold(tenantList, photo);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsOneWidget);
      // Prepared as any camera photo: smaller, and named after its kind.
      expect(find.text('JPEG photo'), findsOneWidget);
      expect(
        find.text('Made smaller from 2.4\u00a0MB to 286\u00a0KB.'),
        findsOneWidget,
      );
      final preview = tester.widget<Image>(find.byType(Image));
      expect((preview.image as MemoryImage).bytes, same(preparedPhoto));
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        isEmpty,
      );
      // Taken: the camera was not opened again, and nothing went up.
      expect(
        ProviderScope.containerOf(tester.element(find.text('Upload')))
            .read(lostPhotoProvider),
        isNull,
      );
      expect(app.picker.calls, isEmpty);
      expect(_called(app), isNot(contains('uploadFile')));
      await expectAccessible(tester);
      await _tap(tester, 'Upload');
      expect(find.text('CNIC, front added.'), findsOneWidget);
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'recordDocument').$2,
        [
          startsWith('${gulberg.id}/tenant/${aliRaza.id}/'),
          'CNIC, front',
          DocumentKind.cnicFront,
        ],
      );
    });

    testWidgets('choosing another file leaves the photo that came back', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _tenant);
      lost(tester).hold(tenantList, app.picker.photo!);
      await tester.pumpAndSettle();
      await _tap(tester, 'Choose another file');
      expect(find.text(recoveredNotice), findsNothing);
      await _tap(tester, 'Choose a file');
      expect(find.text(recoveredNotice), findsNothing);
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('one that came back and cannot be read says why', (
      tester,
    ) async {
      await pumpScreen(tester, _tenant);
      lost(tester).hold(tenantList, ChosenFileFor.gif);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsOneWidget);
      expect(
        find.text(
          'Only photos (JPEG, PNG, WebP or HEIC) and PDFs can be added.',
        ),
        findsOneWidget,
      );
      expect(find.text('Take a photo'), findsOneWidget);
    });

    testWidgets('one waiting when the record opens is opened at once', (
      tester,
    ) async {
      final app = await pumpScreen(tester, () => const _OpensLater());
      lost(tester).hold(tenantList, app.picker.photo!);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsNothing);
      await _tap(tester, 'Open the record');
      expect(find.text(recoveredNotice), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets("another record's photo waits for it", (tester) async {
      final app = await pumpScreen(tester, _tenant);
      final leaseList = (
        portfolioId: gulberg.id,
        owner: (entity: DocumentEntity.lease, id: aliLease.id),
      );
      lost(tester).hold(leaseList, app.picker.photo!);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsNothing);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(DocumentsSection)))
            .read(lostPhotoProvider)
            ?.list,
        leaseList,
      );
    });

    testWidgets('a record no longer in use lets it go', (tester) async {
      final app = await pumpScreen(tester, _archivedUnit);
      lost(tester).hold((
        portfolioId: gulberg.id,
        owner: (entity: DocumentEntity.unit, id: groundFloor.id),
      ), app.picker.photo!);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsNothing);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(DocumentsSection)))
            .read(lostPhotoProvider),
        isNull,
      );
    });

    testWidgets('a viewer lets it go', (tester) async {
      final app = await pumpScreen(tester, _tenant, app: _as(gulbergAsViewer));
      lost(tester).hold(tenantList, app.picker.photo!);
      await tester.pumpAndSettle();
      expect(find.text(recoveredNotice), findsNothing);
      expect(find.text('Upload'), findsNothing);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(DocumentsSection)))
            .read(lostPhotoProvider),
        isNull,
      );
    });
  });

  group('checks', () {
    testWidgets('links are made again while the sheet is open', (tester) async {
      final app = await pumpScreen(tester, _tenant);
      int links() => _called(app).where((c) => c == 'links').length;
      await _tap(tester, 'CNIC front');
      expect(links(), 1);
      // Three minutes on the test's clock: the links are made again in
      // the background, and the buttons stay usable while they are.
      app.documents.gate.close();
      await tester.pump(linksRenewedAfter);
      expect(links(), 2);
      expect(
        tester.widget<MmButton>(find.widgetWithText(MmButton, 'Open')).busy,
        isFalse,
      );
      app.documents.gate.open();
      await tester.pumpAndSettle();
      // Five minutes after the sheet opened, the first links have expired,
      // but a tap opens the new ones at once (in a browser, a tab opened
      // after waiting for a link would be blocked).
      await tester.pump(const Duration(minutes: 2));
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(app.opened, hasLength(1));
      expect(links(), 2);
      // Closing the sheet stops making them.
      await _close(tester);
      await tester.pump(const Duration(minutes: 10));
      expect(links(), 2);
    });

    testWidgets('links made long ago are made again before opening', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _tenant);
      await _tap(tester, 'CNIC front');
      // The renewal failed (no connection), so the first links stay, and
      // grow stale.
      app.documents.linkFailure = const NetworkFailure();
      await tester.pump(linksRenewedAfter);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1, seconds: 30));
      app.documents.linkFailure = null;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(_called(app).where((c) => c == 'links'), hasLength(3));
      expect(app.opened, hasLength(1));
    });

    testWidgets('a name longer than the database takes is cut as typed', (
      tester,
    ) async {
      // 150 Urdu letters with a zabar: 150 characters to the field's
      // counter, 300 code points to the database, which takes 200.
      final marked = '\u0628\u064E' * 150;
      final fits = '\u0628\u064E' * 100;
      await pumpScreen(tester, _tenant);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      await _type(tester, 'Name', marked);
      expect(tester.widget<TextField>(_field('Name')).controller!.text, fits);
      await _close(tester);
      await _tap(tester, 'CNIC front');
      await _tap(tester, 'Rename or change kind');
      await _type(tester, 'Name', marked);
      expect(tester.widget<TextField>(_field('Name')).controller!.text, fits);
      expect(documentNameTooLong(marked), isTrue);
      expect(documentNameTooLong(fits), isFalse);
    });

    testWidgets('a long picked name is cut to fit before it is shown', (
      tester,
    ) async {
      final app = TestApp()
        ..picker.file = ChosenFile(
          name: '${'\u0628\u064E' * 180}.pdf',
          bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
        );
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        '\u0628\u064E' * 100,
      );
    });

    testWidgets('names keep their own direction in Urdu sentences', (
      tester,
    ) async {
      final app = TestApp();
      app.documents.documentsOf(cnicFrontScan.owner)
        ..clear()
        ..add(cnicFrontScan.copyWith(fileName: '2026 (signed)'))
        // Named after its kind: its line has no kind, and starts with the
        // day.
        ..add(cnicBackScan.copyWith(fileName: 'شناختی کارڈ، پچھلا رخ'));
      await pumpScreen(tester, _tenant, app: app, variant: MmVariant.urdu);
      // The format is kept apart, at the end, and every line runs right to
      // left: none starts with a Latin "JPEG".
      expect(shown('2026\u00a0\u00b7 \u2066JPEG\u2069'), findsNWidgets(2));
      expect(
        find.textContaining(RegExp('^\u2066.*JPEG'), findRichText: true),
        findsNothing,
      );
      // The list shows the name in its own direction too.
      await _tap(tester, '\u20662026 (signed)\u2069');
      await _tap(tester, 'حذف کریں');
      expect(find.text('\u20662026 (signed)\u2069 حذف کریں؟'), findsOneWidget);
      await _confirm(tester, 'حذف کریں');
      expect(
        find.text('\u20662026 (signed)\u2069 حذف ہو گئی۔'),
        findsOneWidget,
      );
    });

    testWidgets('the file to upload is described right to left in Urdu', (
      tester,
    ) async {
      await pumpScreen(tester, _tenant, variant: MmVariant.urdu);
      await _tap(tester, 'دستاویز شامل کریں');
      // "10 MB" kept left to right in the help (else it reads "MB 10").
      expect(shown('\u200e10\u00a0MB\u200e تک'), findsOneWidget);
      await _tap(tester, 'تصویر کھینچیں');
      final line = tester.widget<Text>(
        find.text(
          '\u20662.4\u00a0MB\u2069 سے چھوٹی کر کے \u2066286\u00a0KB\u2069 '
          'کر دی گئی۔',
        ),
      );
      // A plain Text: in the UI's direction, not the first size's.
      expect(line.textDirection, isNull);
      expect(
        Directionality.of(tester.element(find.byWidget(line))),
        TextDirection.rtl,
      );
    });

    for (final variant in [MmVariant.largeText, MmVariant.urdu]) {
      testWidgets('subtitles wrap, never cut, at 200% (${variant.name})', (
        tester,
      ) async {
        final app = TestApp();
        app.documents
            .documentsOf(cnicFrontScan.owner)
            .add(
              Document(
                id: '0192d0c4-6666-7000-8000-000000000009',
                owner: cnicFrontScan.owner,
                kind: DocumentKind.rentRegistration,
                storagePath: cnicFrontScan.storagePath.replaceAll(
                  '01.jpg',
                  '09.heic',
                ),
                fileName: 'Registration slip, Gulberg office',
                fileType: DocumentFileType.heic,
                sizeBytes: 1258291,
                createdAt: '2026-10-31T09:00:00+00:00',
              ),
            );
        await pumpScreen(
          tester,
          () => Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: _tenant(),
            ),
          ),
          app: app,
          variant: variant,
          size: const Size(320, 3000),
        );
        final paragraphs = tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byType(MmListTile),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraphs, isNotEmpty);
        for (final paragraph in paragraphs) {
          expect(paragraph.didExceedMaxLines, isFalse);
        }
      });
    }

    testWidgets('a photo the screen cannot show leaves its details', (
      tester,
    ) async {
      final app = TestApp()
        ..picker.preparedJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]);
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Take a photo');
      final image = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(
        () => precacheImage(
          image,
          tester.element(find.byType(Image)),
          onError: (error, stack) {},
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Preview of the photo'), findsNothing);
      expect(find.text('JPEG photo'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets('a HEIC photo kept as it is shows its icon', (tester) async {
      final app = TestApp()
        ..picker.file = ChosenFile(
          name: 'IMG_0042.HEIC',
          bytes: Uint8List.fromList(
            '\u0000\u0000\u0000\u0018ftypheic'.codeUnits,
          ),
        );
      await pumpScreen(tester, _tenant, app: app);
      await _tap(tester, 'Add document');
      await _tap(tester, 'Choose a file');
      expect(find.text('HEIC photo'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('1\u00a0KB'), findsOneWidget);
    });
  });

  testEveryVariant('documents fit at 320 dp', (tester, variant) async {
    await pumpScreen(
      tester,
      _tenant,
      variant: variant,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
    await tester.tap(find.byType(MmListTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}

/// A screen that shows Ali Raza's documents only once asked to: the
/// record opening after a photo came back for it.
class _OpensLater extends StatefulWidget {
  const new();

  @override
  State<_OpensLater> createState() => _OpensLaterState();
}

class _OpensLaterState extends State<_OpensLater> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => _open
      ? _tenant()
      : Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => setState(() => _open = true),
              child: const Text('Open the record'),
            ),
          ),
        );
}

/// Files the fake picker can answer with.
abstract final class ChosenFileFor {
  static final gif = ChosenFile(
    name: 'cnic.gif',
    bytes: Uint8List.fromList('GIF89a'.codeUnits),
  );
}
