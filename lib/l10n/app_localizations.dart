import 'package:flutter/material.dart';

/// 支持的语言列表
class L10n {
  static const all = [
    Locale('en'),           // English
    Locale('zh', 'CN'),     // 简体中文
    Locale('zh', 'TW'),     // 繁體中文
  ];

  static const defaultLocale = Locale('en');
}

/// 应用本地化
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // 获取当前语言代码
  String get languageCode {
    if (locale.countryCode != null) {
      return '${locale.languageCode}_${locale.countryCode}';
    }
    return locale.languageCode;
  }

  // 翻译映射表
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': _enTranslations,
    'zh_CN': _zhCNTranslations,
    'zh_TW': _zhTWTranslations,
  };

  String _translate(String key) {
    final langCode = languageCode;
    // 尝试完整语言代码
    if (_localizedValues.containsKey(langCode)) {
      return _localizedValues[langCode]![key] ?? _localizedValues['en']![key] ?? key;
    }
    // 回退到基础语言代码
    if (_localizedValues.containsKey(locale.languageCode)) {
      return _localizedValues[locale.languageCode]![key] ?? _localizedValues['en']![key] ?? key;
    }
    // 回退到英语
    return _localizedValues['en']![key] ?? key;
  }

  // ===== 通用 =====
  String get appName => _translate('appName');
  String get loading => _translate('loading');
  String get cancel => _translate('cancel');
  String get confirm => _translate('confirm');
  String get save => _translate('save');
  String get delete => _translate('delete');
  String get edit => _translate('edit');
  String get close => _translate('close');
  String get ok => _translate('ok');
  String get error => _translate('error');
  String get success => _translate('success');
  String get warning => _translate('warning');
  String get yes => _translate('yes');
  String get no => _translate('no');

  // ===== 终端 =====
  String get terminal => _translate('terminal');
  String get newSession => _translate('newSession');
  String get closeSession => _translate('closeSession');
  String get sessions => _translate('sessions');
  String get noSessions => _translate('noSessions');
  String get sessionClosed => _translate('sessionClosed');

  // ===== 设置 =====
  String get settings => _translate('settings');
  String get appearance => _translate('appearance');
  String get theme => _translate('theme');
  String get themeSystem => _translate('themeSystem');
  String get themeLight => _translate('themeLight');
  String get themeDark => _translate('themeDark');
  String get fontSize => _translate('fontSize');
  String get fontFamily => _translate('fontFamily');
  String get colorTheme => _translate('colorTheme');
  String get cursorStyle => _translate('cursorStyle');
  String get cursorBlink => _translate('cursorBlink');
  String get behavior => _translate('behavior');
  String get keepScreenOn => _translate('keepScreenOn');
  String get vibration => _translate('vibration');
  String get bellSound => _translate('bellSound');
  String get extraKeys => _translate('extraKeys');
  String get language => _translate('language');
  String get languageSystem => _translate('languageSystem');
  String get about => _translate('about');
  String get version => _translate('version');
  String get terminalMargin => _translate('terminalMargin');

  // ===== Bootstrap =====
  String get bootstrapTitle => _translate('bootstrapTitle');
  String get bootstrapSubtitle => _translate('bootstrapSubtitle');
  String get bootstrapInstall => _translate('bootstrapInstall');
  String get bootstrapInstalling => _translate('bootstrapInstalling');
  String get bootstrapExtracting => _translate('bootstrapExtracting');
  String get bootstrapConfiguring => _translate('bootstrapConfiguring');
  String get bootstrapComplete => _translate('bootstrapComplete');
  String get bootstrapError => _translate('bootstrapError');
  String get bootstrapRetry => _translate('bootstrapRetry');
  String get bootstrapContinue => _translate('bootstrapContinue');

  // ===== 历史记录 =====
  String get history => _translate('history');
  String get historyEmpty => _translate('historyEmpty');
  String get historyClear => _translate('historyClear');
  String get historyClearConfirm => _translate('historyClearConfirm');
  String get historyExport => _translate('historyExport');
  String get historyImport => _translate('historyImport');
  String get historySearch => _translate('historySearch');

  // ===== SSH =====
  String get ssh => _translate('ssh');
  String get sshConnect => _translate('sshConnect');
  String get sshDisconnect => _translate('sshDisconnect');
  String get sshHost => _translate('sshHost');
  String get sshPort => _translate('sshPort');
  String get sshUsername => _translate('sshUsername');
  String get sshPassword => _translate('sshPassword');
  String get sshPrivateKey => _translate('sshPrivateKey');
  String get sshSavedHosts => _translate('sshSavedHosts');
  String get sshNewHost => _translate('sshNewHost');

  // ===== 任务 =====
  String get tasks => _translate('tasks');
  String get taskRunning => _translate('taskRunning');
  String get taskCompleted => _translate('taskCompleted');
  String get taskFailed => _translate('taskFailed');
  String get taskCancel => _translate('taskCancel');

  // ===== 权限 =====
  String get permissionStorage => _translate('permissionStorage');
  String get permissionStorageDesc => _translate('permissionStorageDesc');
  String get permissionDenied => _translate('permissionDenied');
  String get permissionGrant => _translate('permissionGrant');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ===== 英语翻译 =====
const Map<String, String> _enTranslations = {
  // 通用
  'appName': 'Deep Thought',
  'loading': 'Loading...',
  'cancel': 'Cancel',
  'confirm': 'Confirm',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'close': 'Close',
  'ok': 'OK',
  'error': 'Error',
  'success': 'Success',
  'warning': 'Warning',
  'yes': 'Yes',
  'no': 'No',

  // 终端
  'terminal': 'Terminal',
  'newSession': 'New Session',
  'closeSession': 'Close Session',
  'sessions': 'Sessions',
  'noSessions': 'No sessions',
  'sessionClosed': 'Session closed',

  // 设置
  'settings': 'Settings',
  'appearance': 'Appearance',
  'theme': 'Theme',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'fontSize': 'Font Size',
  'fontFamily': 'Font Family',
  'colorTheme': 'Color Theme',
  'cursorStyle': 'Cursor Style',
  'cursorBlink': 'Cursor Blink',
  'behavior': 'Behavior',
  'keepScreenOn': 'Keep Screen On',
  'vibration': 'Vibration',
  'bellSound': 'Bell Sound',
  'extraKeys': 'Extra Keys',
  'language': 'Language',
  'languageSystem': 'System Default',
  'about': 'About',
  'version': 'Version',
  'terminalMargin': 'Terminal Margin',

  // Bootstrap
  'bootstrapTitle': 'Terminal Environment Setup',
  'bootstrapSubtitle': 'Installing required components...',
  'bootstrapInstall': 'Install',
  'bootstrapInstalling': 'Installing...',
  'bootstrapExtracting': 'Extracting files...',
  'bootstrapConfiguring': 'Configuring environment...',
  'bootstrapComplete': 'Setup complete!',
  'bootstrapError': 'Setup failed',
  'bootstrapRetry': 'Retry',
  'bootstrapContinue': 'Continue',

  // 历史记录
  'history': 'History',
  'historyEmpty': 'No history',
  'historyClear': 'Clear History',
  'historyClearConfirm': 'Are you sure you want to clear all history?',
  'historyExport': 'Export History',
  'historyImport': 'Import History',
  'historySearch': 'Search history...',

  // SSH
  'ssh': 'SSH',
  'sshConnect': 'Connect',
  'sshDisconnect': 'Disconnect',
  'sshHost': 'Host',
  'sshPort': 'Port',
  'sshUsername': 'Username',
  'sshPassword': 'Password',
  'sshPrivateKey': 'Private Key',
  'sshSavedHosts': 'Saved Hosts',
  'sshNewHost': 'New Host',

  // 任务
  'tasks': 'Tasks',
  'taskRunning': 'Running',
  'taskCompleted': 'Completed',
  'taskFailed': 'Failed',
  'taskCancel': 'Cancel Task',

  // 权限
  'permissionStorage': 'Storage Permission',
  'permissionStorageDesc': 'Required to access files and storage',
  'permissionDenied': 'Permission denied',
  'permissionGrant': 'Grant Permission',
};

// ===== 简体中文翻译 =====
const Map<String, String> _zhCNTranslations = {
  // 通用
  'appName': 'Deep Thought',
  'loading': '加载中...',
  'cancel': '取消',
  'confirm': '确认',
  'save': '保存',
  'delete': '删除',
  'edit': '编辑',
  'close': '关闭',
  'ok': '确定',
  'error': '错误',
  'success': '成功',
  'warning': '警告',
  'yes': '是',
  'no': '否',

  // 终端
  'terminal': '终端',
  'newSession': '新建会话',
  'closeSession': '关闭会话',
  'sessions': '会话',
  'noSessions': '暂无会话',
  'sessionClosed': '会话已关闭',

  // 设置
  'settings': '设置',
  'appearance': '外观',
  'theme': '主题',
  'themeSystem': '跟随系统',
  'themeLight': '浅色',
  'themeDark': '深色',
  'fontSize': '字体大小',
  'fontFamily': '字体',
  'colorTheme': '配色方案',
  'cursorStyle': '光标样式',
  'cursorBlink': '光标闪烁',
  'behavior': '行为',
  'keepScreenOn': '保持屏幕常亮',
  'vibration': '振动反馈',
  'bellSound': '响铃声音',
  'extraKeys': '扩展按键',
  'language': '语言',
  'languageSystem': '跟随系统',
  'about': '关于',
  'version': '版本',
  'terminalMargin': '终端边距',

  // Bootstrap
  'bootstrapTitle': '终端环境配置',
  'bootstrapSubtitle': '正在安装必要组件...',
  'bootstrapInstall': '安装',
  'bootstrapInstalling': '安装中...',
  'bootstrapExtracting': '解压文件中...',
  'bootstrapConfiguring': '配置环境中...',
  'bootstrapComplete': '配置完成！',
  'bootstrapError': '配置失败',
  'bootstrapRetry': '重试',
  'bootstrapContinue': '继续',

  // 历史记录
  'history': '历史记录',
  'historyEmpty': '暂无历史记录',
  'historyClear': '清除历史记录',
  'historyClearConfirm': '确定要清除所有历史记录吗？',
  'historyExport': '导出历史记录',
  'historyImport': '导入历史记录',
  'historySearch': '搜索历史记录...',

  // SSH
  'ssh': 'SSH',
  'sshConnect': '连接',
  'sshDisconnect': '断开',
  'sshHost': '主机',
  'sshPort': '端口',
  'sshUsername': '用户名',
  'sshPassword': '密码',
  'sshPrivateKey': '私钥',
  'sshSavedHosts': '已保存的主机',
  'sshNewHost': '新建主机',

  // 任务
  'tasks': '任务',
  'taskRunning': '运行中',
  'taskCompleted': '已完成',
  'taskFailed': '失败',
  'taskCancel': '取消任务',

  // 权限
  'permissionStorage': '存储权限',
  'permissionStorageDesc': '需要访问文件和存储',
  'permissionDenied': '权限被拒绝',
  'permissionGrant': '授予权限',
};

// ===== 繁體中文翻译 =====
const Map<String, String> _zhTWTranslations = {
  // 通用
  'appName': 'Deep Thought',
  'loading': '載入中...',
  'cancel': '取消',
  'confirm': '確認',
  'save': '儲存',
  'delete': '刪除',
  'edit': '編輯',
  'close': '關閉',
  'ok': '確定',
  'error': '錯誤',
  'success': '成功',
  'warning': '警告',
  'yes': '是',
  'no': '否',

  // 終端
  'terminal': '終端機',
  'newSession': '新建工作階段',
  'closeSession': '關閉工作階段',
  'sessions': '工作階段',
  'noSessions': '暫無工作階段',
  'sessionClosed': '工作階段已關閉',

  // 設定
  'settings': '設定',
  'appearance': '外觀',
  'theme': '主題',
  'themeSystem': '跟隨系統',
  'themeLight': '淺色',
  'themeDark': '深色',
  'fontSize': '字體大小',
  'fontFamily': '字體',
  'colorTheme': '配色方案',
  'cursorStyle': '游標樣式',
  'cursorBlink': '游標閃爍',
  'behavior': '行為',
  'keepScreenOn': '保持螢幕常亮',
  'vibration': '振動回饋',
  'bellSound': '響鈴聲音',
  'extraKeys': '擴展按鍵',
  'language': '語言',
  'languageSystem': '跟隨系統',
  'about': '關於',
  'version': '版本',
  'terminalMargin': '終端機邊距',

  // Bootstrap
  'bootstrapTitle': '終端機環境設定',
  'bootstrapSubtitle': '正在安裝必要元件...',
  'bootstrapInstall': '安裝',
  'bootstrapInstalling': '安裝中...',
  'bootstrapExtracting': '解壓縮檔案中...',
  'bootstrapConfiguring': '設定環境中...',
  'bootstrapComplete': '設定完成！',
  'bootstrapError': '設定失敗',
  'bootstrapRetry': '重試',
  'bootstrapContinue': '繼續',

  // 歷史記錄
  'history': '歷史記錄',
  'historyEmpty': '暫無歷史記錄',
  'historyClear': '清除歷史記錄',
  'historyClearConfirm': '確定要清除所有歷史記錄嗎？',
  'historyExport': '匯出歷史記錄',
  'historyImport': '匯入歷史記錄',
  'historySearch': '搜尋歷史記錄...',

  // SSH
  'ssh': 'SSH',
  'sshConnect': '連線',
  'sshDisconnect': '斷開',
  'sshHost': '主機',
  'sshPort': '連接埠',
  'sshUsername': '使用者名稱',
  'sshPassword': '密碼',
  'sshPrivateKey': '私鑰',
  'sshSavedHosts': '已儲存的主機',
  'sshNewHost': '新建主機',

  // 任務
  'tasks': '任務',
  'taskRunning': '執行中',
  'taskCompleted': '已完成',
  'taskFailed': '失敗',
  'taskCancel': '取消任務',

  // 權限
  'permissionStorage': '儲存權限',
  'permissionStorageDesc': '需要存取檔案和儲存空間',
  'permissionDenied': '權限被拒絕',
  'permissionGrant': '授予權限',
};
