import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
    Locale('ja'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'当归'**
  String get appName;

  /// No description provided for @privacyTagline.
  ///
  /// In zh, this message translates to:
  /// **'本地记录 · 不上传 · 不调用 AI'**
  String get privacyTagline;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载…'**
  String get loading;

  /// No description provided for @bootstrapError.
  ///
  /// In zh, this message translates to:
  /// **'初始化未完成'**
  String get bootstrapError;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @tasksTab.
  ///
  /// In zh, this message translates to:
  /// **'事项'**
  String get tasksTab;

  /// No description provided for @pastTab.
  ///
  /// In zh, this message translates to:
  /// **'过往'**
  String get pastTab;

  /// No description provided for @notesTab.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get notesTab;

  /// No description provided for @settingsTab.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTab;

  /// No description provided for @tasksTitle.
  ///
  /// In zh, this message translates to:
  /// **'事项'**
  String get tasksTitle;

  /// No description provided for @pastTitle.
  ///
  /// In zh, this message translates to:
  /// **'过往'**
  String get pastTitle;

  /// No description provided for @notesTitle.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get notesTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标题、正文或日期'**
  String get searchHint;

  /// No description provided for @sort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sort;

  /// No description provided for @manualSort.
  ///
  /// In zh, this message translates to:
  /// **'手动排序'**
  String get manualSort;

  /// No description provided for @dateSort.
  ///
  /// In zh, this message translates to:
  /// **'按日期排序'**
  String get dateSort;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'新建事项'**
  String get addTask;

  /// No description provided for @noTasks.
  ///
  /// In zh, this message translates to:
  /// **'还没有事项'**
  String get noTasks;

  /// No description provided for @noTasksHint.
  ///
  /// In zh, this message translates to:
  /// **'记下一件想要完成的事吧。'**
  String get noTasksHint;

  /// No description provided for @quickAdd.
  ///
  /// In zh, this message translates to:
  /// **'快速新建'**
  String get quickAdd;

  /// No description provided for @taskTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'事项名称'**
  String get taskTitleHint;

  /// No description provided for @dueDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get dueDate;

  /// No description provided for @noDate.
  ///
  /// In zh, this message translates to:
  /// **'不设置日期'**
  String get noDate;

  /// No description provided for @plan.
  ///
  /// In zh, this message translates to:
  /// **'计划'**
  String get plan;

  /// No description provided for @planHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：晚饭后开始，预计两个小时'**
  String get planHint;

  /// No description provided for @reminder.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminder;

  /// No description provided for @noReminder.
  ///
  /// In zh, this message translates to:
  /// **'不提醒'**
  String get noReminder;

  /// No description provided for @bodyHint.
  ///
  /// In zh, this message translates to:
  /// **'补充背景、步骤或清单…'**
  String get bodyHint;

  /// No description provided for @bulletedList.
  ///
  /// In zh, this message translates to:
  /// **'项目符号'**
  String get bulletedList;

  /// No description provided for @numberedList.
  ///
  /// In zh, this message translates to:
  /// **'编号列表'**
  String get numberedList;

  /// No description provided for @checklist.
  ///
  /// In zh, this message translates to:
  /// **'勾选清单'**
  String get checklist;

  /// No description provided for @moreSettings.
  ///
  /// In zh, this message translates to:
  /// **'更多设置'**
  String get moreSettings;

  /// No description provided for @moreSettingsWithReminder.
  ///
  /// In zh, this message translates to:
  /// **'更多设置（计划与提醒）'**
  String get moreSettingsWithReminder;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// No description provided for @addToPast.
  ///
  /// In zh, this message translates to:
  /// **'加入过往'**
  String get addToPast;

  /// No description provided for @restoreTask.
  ///
  /// In zh, this message translates to:
  /// **'重新开启'**
  String get restoreTask;

  /// No description provided for @deletedTask.
  ///
  /// In zh, this message translates to:
  /// **'事项已移入最近删除'**
  String get deletedTask;

  /// No description provided for @pastHint.
  ///
  /// In zh, this message translates to:
  /// **'这里是一篇会持续生长的长文档。完成事项后，它会追加到末尾。'**
  String get pastHint;

  /// No description provided for @addPastText.
  ///
  /// In zh, this message translates to:
  /// **'在过往末尾添加文字'**
  String get addPastText;

  /// No description provided for @convertToTask.
  ///
  /// In zh, this message translates to:
  /// **'转为事项'**
  String get convertToTask;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @exportAll.
  ///
  /// In zh, this message translates to:
  /// **'导出全部'**
  String get exportAll;

  /// No description provided for @exportRange.
  ///
  /// In zh, this message translates to:
  /// **'按日期范围导出'**
  String get exportRange;

  /// No description provided for @exportSelection.
  ///
  /// In zh, this message translates to:
  /// **'导出所选内容'**
  String get exportSelection;

  /// No description provided for @emptyPast.
  ///
  /// In zh, this message translates to:
  /// **'过往还是空白'**
  String get emptyPast;

  /// No description provided for @emptyPastHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭事项并选择“加入过往”，记录就会出现在这里。'**
  String get emptyPastHint;

  /// No description provided for @folders.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get folders;

  /// No description provided for @allNotes.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allNotes;

  /// No description provided for @uncategorized.
  ///
  /// In zh, this message translates to:
  /// **'未分类'**
  String get uncategorized;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @newNote.
  ///
  /// In zh, this message translates to:
  /// **'新建笔记'**
  String get newNote;

  /// No description provided for @noteTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'笔记标题'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'从这里开始记录…'**
  String get noteBodyHint;

  /// No description provided for @pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @noNotes.
  ///
  /// In zh, this message translates to:
  /// **'还没有笔记'**
  String get noNotes;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @simplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @japanese.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get japanese;

  /// No description provided for @russian.
  ///
  /// In zh, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @fontStyle.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get fontStyle;

  /// No description provided for @sans.
  ///
  /// In zh, this message translates to:
  /// **'无衬线'**
  String get sans;

  /// No description provided for @serif.
  ///
  /// In zh, this message translates to:
  /// **'衬线'**
  String get serif;

  /// No description provided for @textSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get textSize;

  /// No description provided for @density.
  ///
  /// In zh, this message translates to:
  /// **'卡片密度'**
  String get density;

  /// No description provided for @loose.
  ///
  /// In zh, this message translates to:
  /// **'舒展'**
  String get loose;

  /// No description provided for @compact.
  ///
  /// In zh, this message translates to:
  /// **'紧凑'**
  String get compact;

  /// No description provided for @reminderSettings.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminderSettings;

  /// No description provided for @sound.
  ///
  /// In zh, this message translates to:
  /// **'声音'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In zh, this message translates to:
  /// **'振动'**
  String get vibration;

  /// No description provided for @snooze.
  ///
  /// In zh, this message translates to:
  /// **'稍后提醒'**
  String get snooze;

  /// No description provided for @minutes10.
  ///
  /// In zh, this message translates to:
  /// **'10 分钟'**
  String get minutes10;

  /// No description provided for @minutes30.
  ///
  /// In zh, this message translates to:
  /// **'30 分钟'**
  String get minutes30;

  /// No description provided for @minutes60.
  ///
  /// In zh, this message translates to:
  /// **'60 分钟'**
  String get minutes60;

  /// No description provided for @notificationEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'当归事项提醒'**
  String get notificationEmptyBody;

  /// No description provided for @notificationChannelName.
  ///
  /// In zh, this message translates to:
  /// **'当归事项提醒'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In zh, this message translates to:
  /// **'当归本地事项到期提醒'**
  String get notificationChannelDescription;

  /// No description provided for @reminderHour.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get reminderHour;

  /// No description provided for @reminderMinute.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get reminderMinute;

  /// No description provided for @dataAndBackup.
  ///
  /// In zh, this message translates to:
  /// **'数据与备份'**
  String get dataAndBackup;

  /// No description provided for @autoBackup.
  ///
  /// In zh, this message translates to:
  /// **'每日自动备份'**
  String get autoBackup;

  /// No description provided for @backupFolder.
  ///
  /// In zh, this message translates to:
  /// **'备份文件夹'**
  String get backupFolder;

  /// No description provided for @exportAllData.
  ///
  /// In zh, this message translates to:
  /// **'导出全部数据'**
  String get exportAllData;

  /// No description provided for @restoreBackup.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get restoreBackup;

  /// No description provided for @recentlyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'最近删除'**
  String get recentlyDeleted;

  /// No description provided for @retentionHint.
  ///
  /// In zh, this message translates to:
  /// **'事项和笔记保留 30 天'**
  String get retentionHint;

  /// No description provided for @backupEncryption.
  ///
  /// In zh, this message translates to:
  /// **'备份加密'**
  String get backupEncryption;

  /// No description provided for @privacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get privacy;

  /// No description provided for @localOnlySummary.
  ///
  /// In zh, this message translates to:
  /// **'数据只保存在本机；应用无账号、无广告、无分析统计。'**
  String get localOnlySummary;

  /// No description provided for @help.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get help;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于当归'**
  String get about;

  /// No description provided for @helpTitle.
  ///
  /// In zh, this message translates to:
  /// **'帮助与操作指南'**
  String get helpTitle;

  /// No description provided for @helpSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索操作方法'**
  String get helpSearchHint;

  /// No description provided for @helpNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关帮助'**
  String get helpNoResults;

  /// No description provided for @helpTasks.
  ///
  /// In zh, this message translates to:
  /// **'事项与提醒'**
  String get helpTasks;

  /// No description provided for @helpPast.
  ///
  /// In zh, this message translates to:
  /// **'过往长文档'**
  String get helpPast;

  /// No description provided for @helpNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记与文件夹'**
  String get helpNotes;

  /// No description provided for @helpBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份、恢复与删除'**
  String get helpBackup;

  /// No description provided for @helpPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私与权限'**
  String get helpPrivacy;

  /// No description provided for @permissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'通知权限未开启，提醒已保留但不会响铃。'**
  String get permissionDenied;

  /// No description provided for @reminderScheduled.
  ///
  /// In zh, this message translates to:
  /// **'提醒已安排'**
  String get reminderScheduled;

  /// No description provided for @reminderExpired.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间已过，不会补发。'**
  String get reminderExpired;

  /// No description provided for @reminderStatusPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'权限受限，提醒时间已保留'**
  String get reminderStatusPermissionDenied;

  /// No description provided for @reminderStatusTaskClosed.
  ///
  /// In zh, this message translates to:
  /// **'事项关闭，提醒已暂停'**
  String get reminderStatusTaskClosed;

  /// No description provided for @reminderStatusPaused.
  ///
  /// In zh, this message translates to:
  /// **'提醒已暂停'**
  String get reminderStatusPaused;

  /// No description provided for @openNotificationSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开通知设置'**
  String get openNotificationSettings;

  /// No description provided for @backupCreated.
  ///
  /// In zh, this message translates to:
  /// **'备份已创建'**
  String get backupCreated;

  /// No description provided for @restoreWarning.
  ///
  /// In zh, this message translates to:
  /// **'恢复前会先备份当前数据。请确认来源可信。'**
  String get restoreWarning;

  /// No description provided for @featureComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'此功能将在后续版本完善'**
  String get featureComingSoon;

  /// No description provided for @on.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get on;

  /// No description provided for @off.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get off;

  /// No description provided for @versionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String versionLabel(String version);

  /// No description provided for @reminderSameDay.
  ///
  /// In zh, this message translates to:
  /// **'{date}（{time} 提醒）'**
  String reminderSameDay(String date, String time);

  /// No description provided for @reminderCrossDay.
  ///
  /// In zh, this message translates to:
  /// **'{date}（{reminderDate} {time} 提醒）'**
  String reminderCrossDay(String date, String reminderDate, String time);

  /// No description provided for @reminderOnly.
  ///
  /// In zh, this message translates to:
  /// **'{reminderDate} {time} 提醒'**
  String reminderOnly(String reminderDate, String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
