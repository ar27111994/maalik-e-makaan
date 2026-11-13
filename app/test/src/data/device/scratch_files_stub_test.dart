import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/device/scratch_files_stub.dart';

void main() {
  test('the web keeps no files: there is nothing to delete', () async {
    expect(systemTempPath(), isNull);
    await expectLater(deleteCopies(['/cache'], ['/cache/a.jpg']), completes);
    await expectLater(
      sweepFolder(
        '/cache',
        sharedBefore: DateTime.utc(2026),
        copiesBefore: DateTime.utc(2026),
      ),
      completes,
    );
    await expectLater(sweepOlder('/tmp', DateTime.utc(2026)), completes);
  });
}
