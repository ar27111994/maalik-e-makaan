import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_urdu_material_localizations.dart';

void main() {
  group('MmUrduMaterialLocalizations', () {
    const urduLocale = Locale('ur');

    test('names the days in Urdu, Sunday first, with no Latin letters', () {
      expect(MmUrduMaterialLocalizations.dayNames, hasLength(7));
      expect(MmUrduMaterialLocalizations.dayNames.first, 'اتوار');
      for (final day in MmUrduMaterialLocalizations.dayNames) {
        expect(day, isNot(matches(RegExp('[A-Za-z]'))));
      }
    });

    test('forwards every other word and format to the Urdu ones', () async {
      final base = await GlobalMaterialLocalizations.delegate.load(urduLocale);
      final widgets = await GlobalWidgetsLocalizations.delegate.load(
        urduLocale,
      );
      final urdu = MmUrduMaterialLocalizations(base, widgets);
      final date = DateTime(2026, 9, 30);
      const time = TimeOfDay(hour: 18, minute: 5);
      expect(urdu.base, same(base));
      expect(urdu.narrowWeekdays, MmUrduMaterialLocalizations.dayNames);
      expect(base.narrowWeekdays.first, 'S');
      expect(
        urdu.openAppDrawerTooltip,
        base.openAppDrawerTooltip,
        reason: 'openAppDrawerTooltip',
      );
      expect(
        urdu.backButtonTooltip,
        base.backButtonTooltip,
        reason: 'backButtonTooltip',
      );
      expect(
        urdu.clearButtonTooltip,
        base.clearButtonTooltip,
        reason: 'clearButtonTooltip',
      );
      expect(
        urdu.closeButtonTooltip,
        base.closeButtonTooltip,
        reason: 'closeButtonTooltip',
      );
      expect(
        urdu.deleteButtonTooltip,
        base.deleteButtonTooltip,
        reason: 'deleteButtonTooltip',
      );
      expect(
        urdu.moreButtonTooltip,
        base.moreButtonTooltip,
        reason: 'moreButtonTooltip',
      );
      expect(
        urdu.nextMonthTooltip,
        base.nextMonthTooltip,
        reason: 'nextMonthTooltip',
      );
      expect(
        urdu.previousMonthTooltip,
        base.previousMonthTooltip,
        reason: 'previousMonthTooltip',
      );
      expect(
        urdu.firstPageTooltip,
        base.firstPageTooltip,
        reason: 'firstPageTooltip',
      );
      expect(
        urdu.lastPageTooltip,
        base.lastPageTooltip,
        reason: 'lastPageTooltip',
      );
      expect(
        urdu.nextPageTooltip,
        base.nextPageTooltip,
        reason: 'nextPageTooltip',
      );
      expect(
        urdu.previousPageTooltip,
        base.previousPageTooltip,
        reason: 'previousPageTooltip',
      );
      expect(
        urdu.showMenuTooltip,
        base.showMenuTooltip,
        reason: 'showMenuTooltip',
      );
      expect(
        urdu.licensesPageTitle,
        base.licensesPageTitle,
        reason: 'licensesPageTitle',
      );
      expect(
        urdu.rowsPerPageTitle,
        base.rowsPerPageTitle,
        reason: 'rowsPerPageTitle',
      );
      expect(
        urdu.cancelButtonLabel,
        base.cancelButtonLabel,
        reason: 'cancelButtonLabel',
      );
      expect(
        urdu.closeButtonLabel,
        base.closeButtonLabel,
        reason: 'closeButtonLabel',
      );
      expect(
        urdu.continueButtonLabel,
        base.continueButtonLabel,
        reason: 'continueButtonLabel',
      );
      expect(
        urdu.copyButtonLabel,
        base.copyButtonLabel,
        reason: 'copyButtonLabel',
      );
      expect(
        urdu.cutButtonLabel,
        base.cutButtonLabel,
        reason: 'cutButtonLabel',
      );
      expect(
        urdu.scanTextButtonLabel,
        base.scanTextButtonLabel,
        reason: 'scanTextButtonLabel',
      );
      expect(urdu.okButtonLabel, base.okButtonLabel, reason: 'okButtonLabel');
      expect(
        urdu.pasteButtonLabel,
        base.pasteButtonLabel,
        reason: 'pasteButtonLabel',
      );
      expect(
        urdu.selectAllButtonLabel,
        base.selectAllButtonLabel,
        reason: 'selectAllButtonLabel',
      );
      expect(
        urdu.lookUpButtonLabel,
        base.lookUpButtonLabel,
        reason: 'lookUpButtonLabel',
      );
      expect(
        urdu.searchWebButtonLabel,
        base.searchWebButtonLabel,
        reason: 'searchWebButtonLabel',
      );
      expect(
        urdu.shareButtonLabel,
        base.shareButtonLabel,
        reason: 'shareButtonLabel',
      );
      expect(
        urdu.viewLicensesButtonLabel,
        base.viewLicensesButtonLabel,
        reason: 'viewLicensesButtonLabel',
      );
      expect(
        urdu.anteMeridiemAbbreviation,
        base.anteMeridiemAbbreviation,
        reason: 'anteMeridiemAbbreviation',
      );
      expect(
        urdu.postMeridiemAbbreviation,
        base.postMeridiemAbbreviation,
        reason: 'postMeridiemAbbreviation',
      );
      expect(
        urdu.timePickerHourModeAnnouncement,
        base.timePickerHourModeAnnouncement,
        reason: 'timePickerHourModeAnnouncement',
      );
      expect(
        urdu.timePickerMinuteModeAnnouncement,
        base.timePickerMinuteModeAnnouncement,
        reason: 'timePickerMinuteModeAnnouncement',
      );
      expect(
        urdu.modalBarrierDismissLabel,
        base.modalBarrierDismissLabel,
        reason: 'modalBarrierDismissLabel',
      );
      expect(
        urdu.menuDismissLabel,
        base.menuDismissLabel,
        reason: 'menuDismissLabel',
      );
      expect(urdu.drawerLabel, base.drawerLabel, reason: 'drawerLabel');
      expect(
        urdu.popupMenuLabel,
        base.popupMenuLabel,
        reason: 'popupMenuLabel',
      );
      expect(
        urdu.menuBarMenuLabel,
        base.menuBarMenuLabel,
        reason: 'menuBarMenuLabel',
      );
      expect(urdu.dialogLabel, base.dialogLabel, reason: 'dialogLabel');
      expect(
        urdu.alertDialogLabel,
        base.alertDialogLabel,
        reason: 'alertDialogLabel',
      );
      expect(
        urdu.searchFieldLabel,
        base.searchFieldLabel,
        reason: 'searchFieldLabel',
      );
      expect(
        urdu.currentDateLabel,
        base.currentDateLabel,
        reason: 'currentDateLabel',
      );
      expect(
        urdu.selectedDateLabel,
        base.selectedDateLabel,
        reason: 'selectedDateLabel',
      );
      expect(urdu.scrimLabel, base.scrimLabel, reason: 'scrimLabel');
      expect(
        urdu.bottomSheetLabel,
        base.bottomSheetLabel,
        reason: 'bottomSheetLabel',
      );
      expect(
        urdu.scriptCategory,
        base.scriptCategory,
        reason: 'scriptCategory',
      );
      expect(
        urdu.firstDayOfWeekIndex,
        base.firstDayOfWeekIndex,
        reason: 'firstDayOfWeekIndex',
      );
      expect(urdu.dateSeparator, base.dateSeparator, reason: 'dateSeparator');
      expect(urdu.dateHelpText, base.dateHelpText, reason: 'dateHelpText');
      expect(
        urdu.selectYearSemanticsLabel,
        base.selectYearSemanticsLabel,
        reason: 'selectYearSemanticsLabel',
      );
      expect(
        urdu.unspecifiedDate,
        base.unspecifiedDate,
        reason: 'unspecifiedDate',
      );
      expect(
        urdu.unspecifiedDateRange,
        base.unspecifiedDateRange,
        reason: 'unspecifiedDateRange',
      );
      expect(
        urdu.dateInputLabel,
        base.dateInputLabel,
        reason: 'dateInputLabel',
      );
      expect(
        urdu.dateRangeStartLabel,
        base.dateRangeStartLabel,
        reason: 'dateRangeStartLabel',
      );
      expect(
        urdu.dateRangeEndLabel,
        base.dateRangeEndLabel,
        reason: 'dateRangeEndLabel',
      );
      expect(
        urdu.invalidDateFormatLabel,
        base.invalidDateFormatLabel,
        reason: 'invalidDateFormatLabel',
      );
      expect(
        urdu.invalidDateRangeLabel,
        base.invalidDateRangeLabel,
        reason: 'invalidDateRangeLabel',
      );
      expect(
        urdu.dateOutOfRangeLabel,
        base.dateOutOfRangeLabel,
        reason: 'dateOutOfRangeLabel',
      );
      expect(
        urdu.saveButtonLabel,
        base.saveButtonLabel,
        reason: 'saveButtonLabel',
      );
      expect(
        urdu.datePickerHelpText,
        base.datePickerHelpText,
        reason: 'datePickerHelpText',
      );
      expect(
        urdu.dateRangePickerHelpText,
        base.dateRangePickerHelpText,
        reason: 'dateRangePickerHelpText',
      );
      expect(
        urdu.calendarModeButtonLabel,
        base.calendarModeButtonLabel,
        reason: 'calendarModeButtonLabel',
      );
      expect(
        urdu.inputDateModeButtonLabel,
        base.inputDateModeButtonLabel,
        reason: 'inputDateModeButtonLabel',
      );
      expect(
        urdu.timePickerDialHelpText,
        base.timePickerDialHelpText,
        reason: 'timePickerDialHelpText',
      );
      expect(
        urdu.timePickerInputHelpText,
        base.timePickerInputHelpText,
        reason: 'timePickerInputHelpText',
      );
      expect(
        urdu.timePickerHourLabel,
        base.timePickerHourLabel,
        reason: 'timePickerHourLabel',
      );
      expect(
        urdu.timePickerMinuteLabel,
        base.timePickerMinuteLabel,
        reason: 'timePickerMinuteLabel',
      );
      expect(
        urdu.invalidTimeLabel,
        base.invalidTimeLabel,
        reason: 'invalidTimeLabel',
      );
      expect(
        urdu.dialModeButtonLabel,
        base.dialModeButtonLabel,
        reason: 'dialModeButtonLabel',
      );
      expect(
        urdu.inputTimeModeButtonLabel,
        base.inputTimeModeButtonLabel,
        reason: 'inputTimeModeButtonLabel',
      );
      expect(urdu.signedInLabel, base.signedInLabel, reason: 'signedInLabel');
      expect(
        urdu.hideAccountsLabel,
        base.hideAccountsLabel,
        reason: 'hideAccountsLabel',
      );
      expect(
        urdu.showAccountsLabel,
        base.showAccountsLabel,
        reason: 'showAccountsLabel',
      );
      expect(
        urdu.reorderItemToStart,
        widgets.reorderItemToStart,
        reason: 'reorderItemToStart',
      );
      expect(
        urdu.reorderItemToEnd,
        widgets.reorderItemToEnd,
        reason: 'reorderItemToEnd',
      );
      expect(
        urdu.reorderItemUp,
        widgets.reorderItemUp,
        reason: 'reorderItemUp',
      );
      expect(
        urdu.reorderItemDown,
        widgets.reorderItemDown,
        reason: 'reorderItemDown',
      );
      expect(
        urdu.reorderItemLeft,
        widgets.reorderItemLeft,
        reason: 'reorderItemLeft',
      );
      expect(
        urdu.reorderItemRight,
        widgets.reorderItemRight,
        reason: 'reorderItemRight',
      );
      expect(
        urdu.expandedIconTapHint,
        base.expandedIconTapHint,
        reason: 'expandedIconTapHint',
      );
      expect(
        urdu.collapsedIconTapHint,
        base.collapsedIconTapHint,
        reason: 'collapsedIconTapHint',
      );
      expect(
        urdu.expansionTileExpandedHint,
        base.expansionTileExpandedHint,
        reason: 'expansionTileExpandedHint',
      );
      expect(
        urdu.expansionTileCollapsedHint,
        base.expansionTileCollapsedHint,
        reason: 'expansionTileCollapsedHint',
      );
      expect(
        urdu.expansionTileExpandedTapHint,
        base.expansionTileExpandedTapHint,
        reason: 'expansionTileExpandedTapHint',
      );
      expect(
        urdu.expansionTileCollapsedTapHint,
        base.expansionTileCollapsedTapHint,
        reason: 'expansionTileCollapsedTapHint',
      );
      expect(urdu.expandedHint, base.expandedHint, reason: 'expandedHint');
      expect(urdu.collapsedHint, base.collapsedHint, reason: 'collapsedHint');
      expect(
        urdu.refreshIndicatorSemanticLabel,
        base.refreshIndicatorSemanticLabel,
        reason: 'refreshIndicatorSemanticLabel',
      );
      expect(
        urdu.keyboardKeyAlt,
        base.keyboardKeyAlt,
        reason: 'keyboardKeyAlt',
      );
      expect(
        urdu.keyboardKeyAltGraph,
        base.keyboardKeyAltGraph,
        reason: 'keyboardKeyAltGraph',
      );
      expect(
        urdu.keyboardKeyBackspace,
        base.keyboardKeyBackspace,
        reason: 'keyboardKeyBackspace',
      );
      expect(
        urdu.keyboardKeyCapsLock,
        base.keyboardKeyCapsLock,
        reason: 'keyboardKeyCapsLock',
      );
      expect(
        urdu.keyboardKeyChannelDown,
        base.keyboardKeyChannelDown,
        reason: 'keyboardKeyChannelDown',
      );
      expect(
        urdu.keyboardKeyChannelUp,
        base.keyboardKeyChannelUp,
        reason: 'keyboardKeyChannelUp',
      );
      expect(
        urdu.keyboardKeyControl,
        base.keyboardKeyControl,
        reason: 'keyboardKeyControl',
      );
      expect(
        urdu.keyboardKeyDelete,
        base.keyboardKeyDelete,
        reason: 'keyboardKeyDelete',
      );
      expect(
        urdu.keyboardKeyEject,
        base.keyboardKeyEject,
        reason: 'keyboardKeyEject',
      );
      expect(
        urdu.keyboardKeyEnd,
        base.keyboardKeyEnd,
        reason: 'keyboardKeyEnd',
      );
      expect(
        urdu.keyboardKeyEscape,
        base.keyboardKeyEscape,
        reason: 'keyboardKeyEscape',
      );
      expect(urdu.keyboardKeyFn, base.keyboardKeyFn, reason: 'keyboardKeyFn');
      expect(
        urdu.keyboardKeyHome,
        base.keyboardKeyHome,
        reason: 'keyboardKeyHome',
      );
      expect(
        urdu.keyboardKeyInsert,
        base.keyboardKeyInsert,
        reason: 'keyboardKeyInsert',
      );
      expect(
        urdu.keyboardKeyMeta,
        base.keyboardKeyMeta,
        reason: 'keyboardKeyMeta',
      );
      expect(
        urdu.keyboardKeyMetaMacOs,
        base.keyboardKeyMetaMacOs,
        reason: 'keyboardKeyMetaMacOs',
      );
      expect(
        urdu.keyboardKeyMetaWindows,
        base.keyboardKeyMetaWindows,
        reason: 'keyboardKeyMetaWindows',
      );
      expect(
        urdu.keyboardKeyNumLock,
        base.keyboardKeyNumLock,
        reason: 'keyboardKeyNumLock',
      );
      expect(
        urdu.keyboardKeyNumpad1,
        base.keyboardKeyNumpad1,
        reason: 'keyboardKeyNumpad1',
      );
      expect(
        urdu.keyboardKeyNumpad2,
        base.keyboardKeyNumpad2,
        reason: 'keyboardKeyNumpad2',
      );
      expect(
        urdu.keyboardKeyNumpad3,
        base.keyboardKeyNumpad3,
        reason: 'keyboardKeyNumpad3',
      );
      expect(
        urdu.keyboardKeyNumpad4,
        base.keyboardKeyNumpad4,
        reason: 'keyboardKeyNumpad4',
      );
      expect(
        urdu.keyboardKeyNumpad5,
        base.keyboardKeyNumpad5,
        reason: 'keyboardKeyNumpad5',
      );
      expect(
        urdu.keyboardKeyNumpad6,
        base.keyboardKeyNumpad6,
        reason: 'keyboardKeyNumpad6',
      );
      expect(
        urdu.keyboardKeyNumpad7,
        base.keyboardKeyNumpad7,
        reason: 'keyboardKeyNumpad7',
      );
      expect(
        urdu.keyboardKeyNumpad8,
        base.keyboardKeyNumpad8,
        reason: 'keyboardKeyNumpad8',
      );
      expect(
        urdu.keyboardKeyNumpad9,
        base.keyboardKeyNumpad9,
        reason: 'keyboardKeyNumpad9',
      );
      expect(
        urdu.keyboardKeyNumpad0,
        base.keyboardKeyNumpad0,
        reason: 'keyboardKeyNumpad0',
      );
      expect(
        urdu.keyboardKeyNumpadAdd,
        base.keyboardKeyNumpadAdd,
        reason: 'keyboardKeyNumpadAdd',
      );
      expect(
        urdu.keyboardKeyNumpadComma,
        base.keyboardKeyNumpadComma,
        reason: 'keyboardKeyNumpadComma',
      );
      expect(
        urdu.keyboardKeyNumpadDecimal,
        base.keyboardKeyNumpadDecimal,
        reason: 'keyboardKeyNumpadDecimal',
      );
      expect(
        urdu.keyboardKeyNumpadDivide,
        base.keyboardKeyNumpadDivide,
        reason: 'keyboardKeyNumpadDivide',
      );
      expect(
        urdu.keyboardKeyNumpadEnter,
        base.keyboardKeyNumpadEnter,
        reason: 'keyboardKeyNumpadEnter',
      );
      expect(
        urdu.keyboardKeyNumpadEqual,
        base.keyboardKeyNumpadEqual,
        reason: 'keyboardKeyNumpadEqual',
      );
      expect(
        urdu.keyboardKeyNumpadMultiply,
        base.keyboardKeyNumpadMultiply,
        reason: 'keyboardKeyNumpadMultiply',
      );
      expect(
        urdu.keyboardKeyNumpadParenLeft,
        base.keyboardKeyNumpadParenLeft,
        reason: 'keyboardKeyNumpadParenLeft',
      );
      expect(
        urdu.keyboardKeyNumpadParenRight,
        base.keyboardKeyNumpadParenRight,
        reason: 'keyboardKeyNumpadParenRight',
      );
      expect(
        urdu.keyboardKeyNumpadSubtract,
        base.keyboardKeyNumpadSubtract,
        reason: 'keyboardKeyNumpadSubtract',
      );
      expect(
        urdu.keyboardKeyPageDown,
        base.keyboardKeyPageDown,
        reason: 'keyboardKeyPageDown',
      );
      expect(
        urdu.keyboardKeyPageUp,
        base.keyboardKeyPageUp,
        reason: 'keyboardKeyPageUp',
      );
      expect(
        urdu.keyboardKeyPower,
        base.keyboardKeyPower,
        reason: 'keyboardKeyPower',
      );
      expect(
        urdu.keyboardKeyPowerOff,
        base.keyboardKeyPowerOff,
        reason: 'keyboardKeyPowerOff',
      );
      expect(
        urdu.keyboardKeyPrintScreen,
        base.keyboardKeyPrintScreen,
        reason: 'keyboardKeyPrintScreen',
      );
      expect(
        urdu.keyboardKeyScrollLock,
        base.keyboardKeyScrollLock,
        reason: 'keyboardKeyScrollLock',
      );
      expect(
        urdu.keyboardKeySelect,
        base.keyboardKeySelect,
        reason: 'keyboardKeySelect',
      );
      expect(
        urdu.keyboardKeyShift,
        base.keyboardKeyShift,
        reason: 'keyboardKeyShift',
      );
      expect(
        urdu.keyboardKeySpace,
        base.keyboardKeySpace,
        reason: 'keyboardKeySpace',
      );
      expect(
        urdu.aboutListTileTitle('Maalik-e-Makaan'),
        base.aboutListTileTitle('Maalik-e-Makaan'),
        reason: 'aboutListTileTitle',
      );
      expect(
        urdu.licensesPackageDetailText(3),
        base.licensesPackageDetailText(3),
        reason: 'licensesPackageDetailText',
      );
      expect(
        urdu.pageRowsInfoTitle(1, 10, 42, false),
        base.pageRowsInfoTitle(1, 10, 42, false),
        reason: 'pageRowsInfoTitle',
      );
      expect(
        urdu.tabLabel(tabIndex: 1, tabCount: 3),
        base.tabLabel(tabIndex: 1, tabCount: 3),
        reason: 'tabLabel',
      );
      expect(
        urdu.selectedRowCountTitle(2),
        base.selectedRowCountTitle(2),
        reason: 'selectedRowCountTitle',
      );
      expect(
        urdu.scrimOnTapHint('Ali Raza'),
        base.scrimOnTapHint('Ali Raza'),
        reason: 'scrimOnTapHint',
      );
      expect(
        urdu.timeOfDayFormat(alwaysUse24HourFormat: true),
        base.timeOfDayFormat(alwaysUse24HourFormat: true),
        reason: 'timeOfDayFormat',
      );
      expect(
        urdu.formatDecimal(125000),
        base.formatDecimal(125000),
        reason: 'formatDecimal',
      );
      expect(
        urdu.formatHour(time, alwaysUse24HourFormat: true),
        base.formatHour(time, alwaysUse24HourFormat: true),
        reason: 'formatHour',
      );
      expect(
        urdu.formatMinute(time),
        base.formatMinute(time),
        reason: 'formatMinute',
      );
      expect(
        urdu.formatTimeOfDay(time, alwaysUse24HourFormat: true),
        base.formatTimeOfDay(time, alwaysUse24HourFormat: true),
        reason: 'formatTimeOfDay',
      );
      expect(
        urdu.formatYear(date),
        base.formatYear(date),
        reason: 'formatYear',
      );
      expect(
        urdu.formatCompactDate(date),
        base.formatCompactDate(date),
        reason: 'formatCompactDate',
      );
      expect(
        urdu.formatShortDate(date),
        base.formatShortDate(date),
        reason: 'formatShortDate',
      );
      expect(
        urdu.formatMediumDate(date),
        base.formatMediumDate(date),
        reason: 'formatMediumDate',
      );
      expect(
        urdu.formatFullDate(date),
        base.formatFullDate(date),
        reason: 'formatFullDate',
      );
      expect(
        urdu.formatMonthYear(date),
        base.formatMonthYear(date),
        reason: 'formatMonthYear',
      );
      expect(
        urdu.formatShortMonthDay(date),
        base.formatShortMonthDay(date),
        reason: 'formatShortMonthDay',
      );
      expect(
        urdu.parseCompactDate('30/9/2026'),
        base.parseCompactDate('30/9/2026'),
        reason: 'parseCompactDate',
      );
      expect(
        urdu.dateRangeStartDateSemanticLabel('30 ستمبر'),
        base.dateRangeStartDateSemanticLabel('30 ستمبر'),
        reason: 'dateRangeStartDateSemanticLabel',
      );
      expect(
        urdu.dateRangeEndDateSemanticLabel('30 ستمبر'),
        base.dateRangeEndDateSemanticLabel('30 ستمبر'),
        reason: 'dateRangeEndDateSemanticLabel',
      );
      expect(
        urdu.remainingTextFieldCharacterCount(5),
        base.remainingTextFieldCharacterCount(5),
        reason: 'remainingTextFieldCharacterCount',
      );
    });

    test('its delegate loads it for Urdu only', () async {
      final base = await GlobalMaterialLocalizations.delegate.load(urduLocale);
      final widgets = await GlobalWidgetsLocalizations.delegate.load(
        urduLocale,
      );
      final delegate = MmUrduMaterialLocalizationsDelegate(base, widgets);
      expect(delegate.isSupported(urduLocale), isTrue);
      expect(delegate.isSupported(const Locale('ur', 'PK')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isFalse);
      final loaded = await delegate.load(urduLocale);
      expect(loaded, isA<MmUrduMaterialLocalizations>());
      expect(loaded.narrowWeekdays, MmUrduMaterialLocalizations.dayNames);
      expect(
        delegate.shouldReload(
          MmUrduMaterialLocalizationsDelegate(base, widgets),
        ),
        isFalse,
      );
      final english = await GlobalMaterialLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        delegate.shouldReload(
          MmUrduMaterialLocalizationsDelegate(english, widgets),
        ),
        isTrue,
      );
      final englishWidgets = await GlobalWidgetsLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        delegate.shouldReload(
          MmUrduMaterialLocalizationsDelegate(base, englishWidgets),
        ),
        isTrue,
      );
    });
  });
}
