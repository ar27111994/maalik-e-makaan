@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void main() {
  goldenEveryVariant(
    'mm_password_field',
    () => Localised(
      (context, tr) => GoldenColumn(
        children: [
          MmPasswordField(
            label: tr('New password', 'نیا پاس ورڈ'),
            initialValue: 'gulberg-iii-1985',
            newPassword: true,
            required: true,
            helper: tr('At least 8 characters', 'کم از کم ۸ حروف'),
          ),
          MmPasswordField(
            label: tr('Password', 'پاس ورڈ'),
            initialValue: 'lahore',
            errorText: tr('Wrong password', 'پاس ورڈ درست نہیں'),
          ),
          MmPasswordField(
            label: tr('Old password', 'پرانا پاس ورڈ'),
            initialValue: 'ayesha-khan',
            enabled: false,
          ),
        ],
      ),
    ),
  );
}
