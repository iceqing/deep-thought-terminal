import 'package:flutter/material.dart';

/// 支持的语言列表
class L10n {
  static const all = [
    Locale('en'), // English
    Locale('zh', 'CN'), // 简体中文
    Locale('zh', 'TW'), // 繁體中文
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
      return _localizedValues[langCode]![key] ??
          _localizedValues['en']![key] ??
          key;
    }
    // 回退到基础语言代码
    if (_localizedValues.containsKey(locale.languageCode)) {
      return _localizedValues[locale.languageCode]![key] ??
          _localizedValues['en']![key] ??
          key;
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
  String get localTerminal => _translate('localTerminal');
  String get localTerminalDesc => _translate('localTerminalDesc');
  String get newSession => _translate('newSession');
  String get createSession => _translate('createSession');
  String get closeSession => _translate('closeSession');
  String get renameSession => _translate('renameSession');
  String get sessions => _translate('sessions');
  String get noSessions => _translate('noSessions');
  String get sessionClosed => _translate('sessionClosed');
  String activeSessionsCount(int count) =>
      _translate('activeSessionsCount').replaceAll('{count}', count.toString());
  String get copy => _translate('copy');
  String get paste => _translate('paste');
  String get selectAll => _translate('selectAll');
  String get copyAllOutput => _translate('copyAllOutput');
  String get copyLastLines => _translate('copyLastLines');
  String get copiedToClipboard => _translate('copiedToClipboard');
  String get terminalEmpty => _translate('terminalEmpty');
  String get selected => _translate('selected');
  String get moreActions => _translate('moreActions');
  String get clearSelection => _translate('clearSelection');
  String get manageSSH => _translate('manageSSH');
  String get copySSHPublicKey => _translate('copySSHPublicKey');
  String get noSSHKeyFound => _translate('noSSHKeyFound');
  String get generate => _translate('generate');
  String get rename => _translate('rename');

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
  String get cursor => _translate('cursor');
  String get cursorStyle => _translate('cursorStyle');
  String get cursorBlink => _translate('cursorBlink');
  String get display => _translate('display');
  String get behavior => _translate('behavior');
  String get keepScreenOn => _translate('keepScreenOn');
  String get vibration => _translate('vibration');
  String get bellSound => _translate('bellSound');
  String get input => _translate('input');
  String get gestures => _translate('gestures');
  String get extraKeys => _translate('extraKeys');
  String get language => _translate('language');
  String get languageSystem => _translate('languageSystem');
  String get packageSources => _translate('packageSources');
  String get packageMirror => _translate('packageMirror');
  String get advanced => _translate('advanced');
  String get about => _translate('about');
  String get backendServer => _translate('backendServer');
  String get backendDomain => _translate('backendDomain');
  String get appIntro => _translate('appIntro');
  String get version => _translate('version');
  String get terminalMargin => _translate('terminalMargin');
  String get appTheme => _translate('appTheme');
  String get showExtraKeys => _translate('showExtraKeys');
  String get showExtraKeysDesc => _translate('showExtraKeysDesc');
  String get cursorBlinkDesc => _translate('cursorBlinkDesc');
  String get keepScreenOnDesc => _translate('keepScreenOnDesc');
  String get vibrationDesc => _translate('vibrationDesc');
  String get bellSoundDesc => _translate('bellSoundDesc');
  String get pinchZoom => _translate('pinchZoom');
  String get pinchZoomDesc => _translate('pinchZoomDesc');
  String get volumeUpKey => _translate('volumeUpKey');
  String get volumeDownKey => _translate('volumeDownKey');
  String get selectAction => _translate('selectAction');
  String get customAction => _translate('customAction');
  String get customActionHint => _translate('customActionHint');
  String get clearTerminal => _translate('clearTerminal');
  String get terminalCleared => _translate('terminalCleared');
  String get resetToDefaults => _translate('resetToDefaults');
  String get resetToDefaultsDesc => _translate('resetToDefaultsDesc');
  String get resetSettings => _translate('resetSettings');
  String get resetSettingsConfirm => _translate('resetSettingsConfirm');
  String get showDebugInfo => _translate('showDebugInfo');
  String get showDebugInfoDesc => _translate('showDebugInfoDesc');
  String get charWidthDebug => _translate('charWidthDebug');
  String get charWidthDebugDesc => _translate('charWidthDebugDesc');
  String get selectFont => _translate('selectFont');
  String get selectTheme => _translate('selectTheme');
  String get selectAppTheme => _translate('selectAppTheme');
  String get selectCursorStyle => _translate('selectCursorStyle');
  String get selectLanguage => _translate('selectLanguage');
  String get selectMirror => _translate('selectMirror');
  String get shell => _translate('shell');
  String get defaultShell => _translate('defaultShell');
  String get defaultShellDesc => _translate('defaultShellDesc');
  String get selectShell => _translate('selectShell');
  String get shellNotInstalled => _translate('shellNotInstalled');

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
  String get historyExportDesc => _translate('historyExportDesc');
  String get historyImport => _translate('historyImport');
  String get historyImportDesc => _translate('historyImportDesc');
  String get historySearch => _translate('historySearch');
  String get historyStats => _translate('historyStats');
  String get historyView => _translate('historyView');
  String get historyViewDesc => _translate('historyViewDesc');
  String get historyClearDesc => _translate('historyClearDesc');
  String get historyCleared => _translate('historyCleared');
  String get historyDebugInfo => _translate('historyDebugInfo');

  // ===== SSH =====
  String get ssh => _translate('ssh');
  String get sshConnections => _translate('sshConnections');
  String get sshConnect => _translate('sshConnect');
  String get sshDisconnect => _translate('sshDisconnect');
  String get sshHost => _translate('sshHost');
  String get sshPort => _translate('sshPort');
  String get sshUsername => _translate('sshUsername');
  String get sshPassword => _translate('sshPassword');
  String get sshPrivateKey => _translate('sshPrivateKey');
  String get sshSavedHosts => _translate('sshSavedHosts');
  String get sshNewHost => _translate('sshNewHost');
  String get sshNoHosts => _translate('sshNoHosts');
  String get addHost => _translate('addHost');
  String get editHost => _translate('editHost');
  String get deleteHost => _translate('deleteHost');
  String get deleteHostConfirm => _translate('deleteHostConfirm');
  String get hostRequired => _translate('hostRequired');
  String get displayName => _translate('displayName');
  String get optional => _translate('optional');

  // ===== SSH Config =====
  String get sshConfig => _translate('sshConfig');
  String get sshConfigDesc => _translate('sshConfigDesc');
  String get sshConfigGlobal => _translate('sshConfigGlobal');
  String get sshConfigAddHost => _translate('sshConfigAddHost');
  String get sshConfigDeleteHost => _translate('sshConfigDeleteHost');
  String sshConfigDeleteConfirm(String name) =>
      _translate('sshConfigDeleteConfirm').replaceAll('{name}', name);
  String get sshConfigSaved => _translate('sshConfigSaved');
  String get sshConfigKeepAlive => _translate('sshConfigKeepAlive');
  String get sshConfigConnection => _translate('sshConfigConnection');
  String get sshConfigAuth => _translate('sshConfigAuth');
  String get sshConfigSecurity => _translate('sshConfigSecurity');
  String get sshConfigPerformance => _translate('sshConfigPerformance');
  String get sshConfigHostPattern => _translate('sshConfigHostPattern');
  String get sshConfigHostPatternHint => _translate('sshConfigHostPatternHint');
  String get sshConfigServerAliveInterval =>
      _translate('sshConfigServerAliveInterval');
  String get sshConfigServerAliveCountMax =>
      _translate('sshConfigServerAliveCountMax');
  String get sshConfigConnectTimeout => _translate('sshConfigConnectTimeout');
  String get sshConfigConnectionAttempts =>
      _translate('sshConfigConnectionAttempts');
  String get sshConfigIdentityFile => _translate('sshConfigIdentityFile');
  String get sshConfigPreferredAuth => _translate('sshConfigPreferredAuth');
  String get sshConfigStrictHostKey => _translate('sshConfigStrictHostKey');
  String get sshConfigCompression => _translate('sshConfigCompression');
  String get sshConfigForwardAgent => _translate('sshConfigForwardAgent');
  String get sshConfigTcpKeepAlive => _translate('sshConfigTcpKeepAlive');
  String get sshConfigApplyKeepAlive => _translate('sshConfigApplyKeepAlive');
  String get sshConfigApplyKeepAliveDesc =>
      _translate('sshConfigApplyKeepAliveDesc');
  String get sshConfigNoFile => _translate('sshConfigNoFile');
  String get sshConfigCreateNew => _translate('sshConfigCreateNew');

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

  // ===== 键盘与命令 =====
  String get keyEsc => _translate('keyEsc');
  String get keyTab => _translate('keyTab');
  String get keyCtrl => _translate('keyCtrl');
  String get keyAlt => _translate('keyAlt');
  String get keyHome => _translate('keyHome');
  String get keyEnd => _translate('keyEnd');
  String get keyPgUp => _translate('keyPgUp');
  String get keyPgDn => _translate('keyPgDn');
  String get keyIns => _translate('keyIns');
  String get keyDel => _translate('keyDel');
  String get keyEnter => _translate('keyEnter');

  // ===== 文件管理器 =====
  String get fileManager => _translate('fileManager');
  String get openFile => _translate('openFile');
  String get editFile => _translate('editFile');
  String get fileInfo => _translate('fileInfo');
  String get fileName => _translate('fileName');
  String get fileSize => _translate('fileSize');
  String get modifiedDate => _translate('modifiedDate');
  String get emptyDirectory => _translate('emptyDirectory');
  String get back => _translate('back');
  String get home => _translate('home');
  String get refresh => _translate('refresh');
  String get storageDirectories => _translate('storageDirectories');
  String get retry => _translate('retry');
  String get openCurrentDirectory => _translate('openCurrentDirectory');
  String get newFolder => _translate('newFolder');
  String get enterFolderName => _translate('enterFolderName');
  String get hideHiddenFiles => _translate('hideHiddenFiles');
  String get showHiddenFiles => _translate('showHiddenFiles');
  String get openInSystem => _translate('openInSystem');
  String get goBackHistory => _translate('goBackHistory');
  String get keyBackspace => _translate('keyBackspace');
  String get categorySymbols => _translate('categorySymbols');
  String get categoryFKeys => _translate('categoryFKeys');
  String get categoryCommands => _translate('categoryCommands');
  String get categoryNav => _translate('categoryNav');
  String get categoryTermux => _translate('categoryTermux');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
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
  bool shouldReload(_AppLocalizationsDelegate old) => true;
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
  'localTerminal': 'Local Terminal',
  'localTerminalDesc': 'Start a new local shell session',
  'newSession': 'New Session',
  'createSession': 'Create Session',
  'closeSession': 'Close Session',
  'renameSession': 'Rename Session',
  'sessions': 'Sessions',
  'noSessions': 'No sessions',
  'sessionClosed': 'Session closed',
  'activeSessionsCount': '{count} active session(s)',
  'copy': 'Copy',
  'paste': 'Paste',
  'selectAll': 'Select All',
  'copyAllOutput': 'Copy All Output',
  'copyLastLines': 'Copy Last 50 Lines',
  'copiedToClipboard': 'Copied to clipboard',
  'terminalEmpty': 'Terminal is empty',
  'selected': 'Selected',
  'moreActions': 'More actions',
  'clearSelection': 'Clear selection',
  'manageSSH': 'Manage SSH',
  'copySSHPublicKey': 'Copy SSH Public Key',
  'noSSHKeyFound': 'No SSH public key found. Run: ssh-keygen',
  'generate': 'Generate',
  'rename': 'Rename',

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
  'cursor': 'Cursor',
  'cursorStyle': 'Cursor Style',
  'cursorBlink': 'Cursor Blink',
  'display': 'Display',
  'behavior': 'Behavior',
  'keepScreenOn': 'Keep Screen On',
  'vibration': 'Vibration',
  'bellSound': 'Bell Sound',
  'input': 'Input',
  'gestures': 'Gestures',
  'extraKeys': 'Extra Keys',
  'language': 'Language',
  'languageSystem': 'System Default',
  'packageSources': 'Package Sources',
  'packageMirror': 'Package Mirror',
  'advanced': 'Advanced',
  'about': 'About',
  'backendServer': 'Backend Server',
  'backendDomain': 'Backend Domain',
  'appIntro': 'A Flutter terminal emulator inspired by Termux.',
  'version': 'Version',
  'terminalMargin': 'Terminal Margin',
  'appTheme': 'App Theme',
  'showExtraKeys': 'Show Extra Keys',
  'showExtraKeysDesc': 'Show additional keyboard row',
  'cursorBlinkDesc': 'Animate cursor blinking',
  'keepScreenOnDesc': 'Prevent screen from turning off',
  'vibrationDesc': 'Haptic feedback on key press',
  'bellSoundDesc': 'Play sound on bell character',
  'pinchZoom': 'Pinch to Zoom',
  'pinchZoomDesc': 'Use two fingers to resize text',
  'volumeUpKey': 'Volume Up Key',
  'volumeDownKey': 'Volume Down Key',
  'selectAction': 'Select Action',
  'customAction': 'Custom',
  'customActionHint': 'e.g. \\x1b[A for Up arrow',
  'clearTerminal': 'Clear Terminal',
  'terminalCleared': 'Terminal cleared',
  'resetToDefaults': 'Reset to Defaults',
  'resetToDefaultsDesc': 'Restore all settings to default values',
  'resetSettings': 'Reset Settings',
  'resetSettingsConfirm':
      'Are you sure you want to reset all settings to their default values?',
  'showDebugInfo': 'Show Debug Info',
  'showDebugInfoDesc': 'Display terminal debug overlay',
  'charWidthDebug': 'Character Width Debug',
  'charWidthDebugDesc': 'Diagnose Powerline/Nerd Font issues',
  'selectFont': 'Select Font',
  'selectTheme': 'Select Theme',
  'selectAppTheme': 'Select App Theme',
  'selectCursorStyle': 'Select Cursor Style',
  'selectLanguage': 'Select Language',
  'selectMirror': 'Select Package Mirror',
  'shell': 'Shell',
  'defaultShell': 'Default Shell',
  'defaultShellDesc': 'Shell to use for new sessions',
  'selectShell': 'Select Shell',
  'shellNotInstalled': 'Not installed',

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
  'historyExportDesc': 'Backup history to JSON file',
  'historyImport': 'Import History',
  'historyImportDesc': 'Restore history from JSON file',
  'historySearch': 'Search history...',
  'historyStats': 'History Statistics',
  'historyView': 'View History',
  'historyViewDesc': 'Browse and search command history',
  'historyClearDesc': 'Delete all command history',
  'historyCleared': 'History cleared',
  'historyDebugInfo': 'History Debug Info',

  // SSH
  'ssh': 'SSH',
  'sshConnections': 'SSH Connections',
  'sshConnect': 'Connect',
  'sshDisconnect': 'Disconnect',
  'sshHost': 'Host',
  'sshPort': 'Port',
  'sshUsername': 'Username',
  'sshPassword': 'Password',
  'sshPrivateKey': 'Private Key',
  'sshSavedHosts': 'Saved Hosts',
  'sshNewHost': 'New Host',
  'sshNoHosts': 'No SSH hosts saved',
  'addHost': 'Add Host',
  'editHost': 'Edit SSH Host',
  'deleteHost': 'Delete Host',
  'deleteHostConfirm': 'Are you sure you want to delete {name}?',
  'hostRequired': 'Host is required',
  'displayName': 'Display Name',
  'optional': 'Optional',

  // SSH Config
  'sshConfig': 'SSH Config',
  'sshConfigDesc': 'Manage SSH client configuration',
  'sshConfigGlobal': 'Global (all hosts)',
  'sshConfigAddHost': 'Add Host Block',
  'sshConfigDeleteHost': 'Delete Host Block',
  'sshConfigDeleteConfirm': 'Delete config for {name}?',
  'sshConfigSaved': 'SSH config saved',
  'sshConfigKeepAlive': 'Keep-Alive',
  'sshConfigConnection': 'Connection',
  'sshConfigAuth': 'Authentication',
  'sshConfigSecurity': 'Security',
  'sshConfigPerformance': 'Performance',
  'sshConfigHostPattern': 'Host Pattern',
  'sshConfigHostPatternHint': 'e.g. *, myserver, 192.168.1.*',
  'sshConfigServerAliveInterval': 'Server Alive Interval (sec)',
  'sshConfigServerAliveCountMax': 'Server Alive Count Max',
  'sshConfigConnectTimeout': 'Connect Timeout (sec)',
  'sshConfigConnectionAttempts': 'Connection Attempts',
  'sshConfigIdentityFile': 'Identity File',
  'sshConfigPreferredAuth': 'Preferred Auth Methods',
  'sshConfigStrictHostKey': 'Strict Host Key Checking',
  'sshConfigCompression': 'Compression',
  'sshConfigForwardAgent': 'Forward Agent',
  'sshConfigTcpKeepAlive': 'TCP Keep-Alive',
  'sshConfigApplyKeepAlive': 'Apply Keep-Alive Defaults',
  'sshConfigApplyKeepAliveDesc':
      'Set ServerAliveInterval=30, ServerAliveCountMax=3',
  'sshConfigNoFile': 'No SSH config file found',
  'sshConfigCreateNew': 'Create config file',

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

  // 键盘与命令
  'keyEsc': 'ESC',
  'keyTab': 'TAB',
  'keyCtrl': 'CTRL',
  'keyAlt': 'ALT',
  'keyHome': 'HOME',
  'keyEnd': 'END',
  'keyPgUp': 'PGUP',
  'keyPgDn': 'PGDN',
  'keyIns': 'INS',
  'keyDel': 'DEL',
  'keyEnter': 'ENTER',
  'keyBackspace': 'DEL',
  'categorySymbols': 'Symbols',
  'categoryFKeys': 'F-Keys',
  'categoryCommands': 'Cmds',
  'categoryNav': 'Nav',
  'categoryTermux': 'Termux',

  // File Manager
  'fileManager': 'File Manager',
  'openFile': 'Open File',
  'editFile': 'Edit File',
  'fileInfo': 'File Info',
  'fileName': 'Name',
  'fileSize': 'Size',
  'modifiedDate': 'Modified',
  'emptyDirectory': 'Empty Directory',
  'back': 'Back',
  'home': 'Home',
  'refresh': 'Refresh',
  'storageDirectories': 'Storage Locations',
  'retry': 'Retry',
  'openCurrentDirectory': 'Open Current Directory',
  'newFolder': 'New Folder',
  'enterFolderName': 'Enter folder name',
  'hideHiddenFiles': 'Hide Hidden Files',
  'showHiddenFiles': 'Show Hidden Files',
  'openInSystem': 'Open in System',
  'goBackHistory': 'Go Back',
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
  'localTerminal': '本地终端',
  'localTerminalDesc': '启动新的本地 Shell 会话',
  'newSession': '新建会话',
  'createSession': '创建会话',
  'closeSession': '关闭会话',
  'renameSession': '重命名会话',
  'sessions': '会话',
  'noSessions': '暂无会话',
  'sessionClosed': '会话已关闭',
  'activeSessionsCount': '{count} 个活动会话',
  'copy': '复制',
  'paste': '粘贴',
  'selectAll': '全选',
  'copyAllOutput': '复制全部输出',
  'copyLastLines': '复制最后50行',
  'copiedToClipboard': '已复制到剪贴板',
  'terminalEmpty': '终端为空',
  'selected': '已选择',
  'moreActions': '更多操作',
  'clearSelection': '清除选择',
  'manageSSH': '管理 SSH',
  'copySSHPublicKey': '复制 SSH 公钥',
  'noSSHKeyFound': '未找到 SSH 公钥，请运行: ssh-keygen',
  'generate': '生成',
  'rename': '重命名',

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
  'cursor': '光标',
  'cursorStyle': '光标样式',
  'cursorBlink': '光标闪烁',
  'display': '显示',
  'behavior': '行为',
  'keepScreenOn': '保持屏幕常亮',
  'vibration': '振动反馈',
  'bellSound': '响铃声音',
  'input': '输入',
  'gestures': '手势',
  'extraKeys': '扩展按键',
  'language': '语言',
  'languageSystem': '跟随系统',
  'packageSources': '软件源',
  'packageMirror': '软件镜像源',
  'advanced': '高级',
  'about': '关于',
  'backendServer': '后端服务器',
  'backendDomain': '后端域名',
  'appIntro': '一款受 Termux 启发的 Flutter 终端模拟器。',
  'version': '版本',
  'terminalMargin': '终端边距',
  'appTheme': '应用主题',
  'showExtraKeys': '显示扩展按键',
  'showExtraKeysDesc': '显示额外的键盘行',
  'cursorBlinkDesc': '光标闪烁动画',
  'keepScreenOnDesc': '防止屏幕自动关闭',
  'vibrationDesc': '按键触感反馈',
  'bellSoundDesc': '响铃字符时播放声音',
  'pinchZoom': '双指缩放',
  'pinchZoomDesc': '双指缩放调整字体大小',
  'volumeUpKey': '音量+按键',
  'volumeDownKey': '音量-按键',
  'selectAction': '选择动作',
  'customAction': '自定义',
  'customActionHint': '例如 \\x1b[A 表示方向上',
  'clearTerminal': '清除终端',
  'terminalCleared': '终端已清除',
  'resetToDefaults': '恢复默认设置',
  'resetToDefaultsDesc': '将所有设置恢复为默认值',
  'resetSettings': '重置设置',
  'resetSettingsConfirm': '确定要将所有设置恢复为默认值吗？',
  'showDebugInfo': '显示调试信息',
  'showDebugInfoDesc': '显示终端调试覆盖层',
  'charWidthDebug': '字符宽度调试',
  'charWidthDebugDesc': '诊断 Powerline/Nerd Font 问题',
  'selectFont': '选择字体',
  'selectTheme': '选择主题',
  'selectAppTheme': '选择应用主题',
  'selectCursorStyle': '选择光标样式',
  'selectLanguage': '选择语言',
  'selectMirror': '选择软件镜像源',
  'shell': 'Shell',
  'defaultShell': '默认 Shell',
  'defaultShellDesc': '新会话使用的 Shell',
  'selectShell': '选择 Shell',
  'shellNotInstalled': '未安装',

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
  'historyExportDesc': '备份历史记录到 JSON 文件',
  'historyImport': '导入历史记录',
  'historyImportDesc': '从 JSON 文件恢复历史记录',
  'historySearch': '搜索历史记录...',
  'historyStats': '历史记录统计',
  'historyView': '查看历史记录',
  'historyViewDesc': '浏览和搜索命令历史',
  'historyClearDesc': '删除所有命令历史',
  'historyCleared': '历史记录已清除',
  'historyDebugInfo': '历史记录调试信息',

  // SSH
  'ssh': 'SSH',
  'sshConnections': 'SSH 连接',
  'sshConnect': '连接',
  'sshDisconnect': '断开',
  'sshHost': '主机',
  'sshPort': '端口',
  'sshUsername': '用户名',
  'sshPassword': '密码',
  'sshPrivateKey': '私钥',
  'sshSavedHosts': '已保存的主机',
  'sshNewHost': '新建主机',
  'sshNoHosts': '暂无保存的 SSH 主机',
  'addHost': '添加主机',
  'editHost': '编辑 SSH 主机',
  'deleteHost': '删除主机',
  'deleteHostConfirm': '确定要删除 {name} 吗？',
  'hostRequired': '主机地址不能为空',
  'displayName': '显示名称',
  'optional': '可选',

  // SSH Config
  'sshConfig': 'SSH 配置',
  'sshConfigDesc': '管理 SSH 客户端配置',
  'sshConfigGlobal': '全局（所有主机）',
  'sshConfigAddHost': '添加主机配置',
  'sshConfigDeleteHost': '删除主机配置',
  'sshConfigDeleteConfirm': '确定要删除 {name} 的配置吗？',
  'sshConfigSaved': 'SSH 配置已保存',
  'sshConfigKeepAlive': '保活',
  'sshConfigConnection': '连接',
  'sshConfigAuth': '认证',
  'sshConfigSecurity': '安全',
  'sshConfigPerformance': '性能',
  'sshConfigHostPattern': '主机模式',
  'sshConfigHostPatternHint': '例如 *, myserver, 192.168.1.*',
  'sshConfigServerAliveInterval': '服务器存活间隔（秒）',
  'sshConfigServerAliveCountMax': '服务器存活最大次数',
  'sshConfigConnectTimeout': '连接超时（秒）',
  'sshConfigConnectionAttempts': '连接尝试次数',
  'sshConfigIdentityFile': '密钥文件',
  'sshConfigPreferredAuth': '首选认证方式',
  'sshConfigStrictHostKey': '严格主机密钥检查',
  'sshConfigCompression': '压缩',
  'sshConfigForwardAgent': '转发代理',
  'sshConfigTcpKeepAlive': 'TCP 保活',
  'sshConfigApplyKeepAlive': '应用保活默认值',
  'sshConfigApplyKeepAliveDesc':
      '设置 ServerAliveInterval=30, ServerAliveCountMax=3',
  'sshConfigNoFile': '未找到 SSH 配置文件',
  'sshConfigCreateNew': '创建配置文件',

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

  // 键盘与命令
  'keyEsc': 'ESC',
  'keyTab': 'TAB',
  'keyCtrl': 'CTRL',
  'keyAlt': 'ALT',
  'keyHome': 'HOME',
  'keyEnd': 'END',
  'keyPgUp': '上翻',
  'keyPgDn': '下翻',
  'keyIns': '插入',
  'keyDel': '删除',
  'keyEnter': '回车',
  'keyBackspace': '退格',
  'categorySymbols': '符号',
  'categoryFKeys': 'F键',
  'categoryCommands': '命令',
  'categoryNav': '导航',
  'categoryTermux': 'Termux',

  // 文件管理器
  'fileManager': '文件管理器',
  'openFile': '打开文件',
  'editFile': '编辑文件',
  'fileInfo': '文件信息',
  'fileName': '名称',
  'fileSize': '大小',
  'modifiedDate': '修改日期',
  'emptyDirectory': '空目录',
  'back': '返回',
  'home': '主目录',
  'refresh': '刷新',
  'storageDirectories': '存储位置',
  'retry': '重试',
  'openCurrentDirectory': '打开当前目录',
  'newFolder': '新建文件夹',
  'enterFolderName': '输入文件夹名称',
  'hideHiddenFiles': '关闭隐藏文件',
  'showHiddenFiles': '显示隐藏文件',
  'openInSystem': '在系统打开',
  'goBackHistory': '返回上一次位置',
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
  'localTerminal': '本機終端機',
  'localTerminalDesc': '啟動新的本機 Shell 工作階段',
  'newSession': '新建工作階段',
  'createSession': '建立工作階段',
  'closeSession': '關閉工作階段',
  'renameSession': '重新命名工作階段',
  'sessions': '工作階段',
  'noSessions': '暫無工作階段',
  'sessionClosed': '工作階段已關閉',
  'activeSessionsCount': '{count} 個活動工作階段',
  'copy': '複製',
  'paste': '貼上',
  'selectAll': '全選',
  'copyAllOutput': '複製全部輸出',
  'copyLastLines': '複製最後50行',
  'copiedToClipboard': '已複製到剪貼簿',
  'terminalEmpty': '終端機為空',
  'selected': '已選擇',
  'moreActions': '更多操作',
  'clearSelection': '清除選擇',
  'manageSSH': '管理 SSH',
  'copySSHPublicKey': '複製 SSH 公鑰',
  'noSSHKeyFound': '未找到 SSH 公鑰，請執行: ssh-keygen',
  'generate': '產生',
  'rename': '重新命名',

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
  'cursor': '游標',
  'cursorStyle': '游標樣式',
  'cursorBlink': '游標閃爍',
  'display': '顯示',
  'behavior': '行為',
  'keepScreenOn': '保持螢幕常亮',
  'vibration': '振動回饋',
  'bellSound': '響鈴聲音',
  'input': '輸入',
  'gestures': '手勢',
  'extraKeys': '擴展按鍵',
  'language': '語言',
  'languageSystem': '跟隨系統',
  'packageSources': '軟體源',
  'packageMirror': '軟體鏡像源',
  'advanced': '進階',
  'about': '關於',
  'backendServer': '後端伺服器',
  'backendDomain': '後端網域',
  'appIntro': '一款受 Termux 啟發的 Flutter 終端模擬器。',
  'version': '版本',
  'terminalMargin': '終端機邊距',
  'appTheme': '應用程式主題',
  'showExtraKeys': '顯示擴展按鍵',
  'showExtraKeysDesc': '顯示額外的鍵盤列',
  'cursorBlinkDesc': '游標閃爍動畫',
  'keepScreenOnDesc': '防止螢幕自動關閉',
  'vibrationDesc': '按鍵觸感回饋',
  'bellSoundDesc': '響鈴字元時播放聲音',
  'pinchZoom': '雙指縮放',
  'pinchZoomDesc': '雙指縮放調整字體大小',
  'volumeUpKey': '音量+按鍵',
  'volumeDownKey': '音量-按鍵',
  'selectAction': '選擇動作',
  'customAction': '自訂',
  'customActionHint': '例如 \\x1b[A 表示方向上',
  'clearTerminal': '清除終端機',
  'terminalCleared': '終端機已清除',
  'resetToDefaults': '恢復預設設定',
  'resetToDefaultsDesc': '將所有設定恢復為預設值',
  'resetSettings': '重設設定',
  'resetSettingsConfirm': '確定要將所有設定恢復為預設值嗎？',
  'showDebugInfo': '顯示除錯資訊',
  'showDebugInfoDesc': '顯示終端機除錯覆蓋層',
  'charWidthDebug': '字元寬度除錯',
  'charWidthDebugDesc': '診斷 Powerline/Nerd Font 問題',
  'selectFont': '選擇字體',
  'selectTheme': '選擇主題',
  'selectAppTheme': '選擇應用程式主題',
  'selectCursorStyle': '選擇游標樣式',
  'selectLanguage': '選擇語言',
  'selectMirror': '選擇軟體鏡像源',
  'shell': 'Shell',
  'defaultShell': '預設 Shell',
  'defaultShellDesc': '新工作階段使用的 Shell',
  'selectShell': '選擇 Shell',
  'shellNotInstalled': '未安裝',

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
  'historyExportDesc': '備份歷史記錄到 JSON 檔案',
  'historyImport': '匯入歷史記錄',
  'historyImportDesc': '從 JSON 檔案恢復歷史記錄',
  'historySearch': '搜尋歷史記錄...',
  'historyStats': '歷史記錄統計',
  'historyView': '檢視歷史記錄',
  'historyViewDesc': '瀏覽和搜尋命令歷史',
  'historyClearDesc': '刪除所有命令歷史',
  'historyCleared': '歷史記錄已清除',
  'historyDebugInfo': '歷史記錄除錯資訊',

  // SSH
  'ssh': 'SSH',
  'sshConnections': 'SSH 連線',
  'sshConnect': '連線',
  'sshDisconnect': '斷開',
  'sshHost': '主機',
  'sshPort': '連接埠',
  'sshUsername': '使用者名稱',
  'sshPassword': '密碼',
  'sshPrivateKey': '私鑰',
  'sshSavedHosts': '已儲存的主機',
  'sshNewHost': '新建主機',
  'sshNoHosts': '暫無儲存的 SSH 主機',
  'addHost': '新增主機',
  'editHost': '編輯 SSH 主機',
  'deleteHost': '刪除主機',
  'deleteHostConfirm': '確定要刪除 {name} 嗎？',
  'hostRequired': '主機位址不能為空',
  'displayName': '顯示名稱',
  'optional': '可選',

  // SSH Config
  'sshConfig': 'SSH 設定',
  'sshConfigDesc': '管理 SSH 用戶端設定',
  'sshConfigGlobal': '全域（所有主機）',
  'sshConfigAddHost': '新增主機設定',
  'sshConfigDeleteHost': '刪除主機設定',
  'sshConfigDeleteConfirm': '確定要刪除 {name} 的設定嗎？',
  'sshConfigSaved': 'SSH 設定已儲存',
  'sshConfigKeepAlive': '保活',
  'sshConfigConnection': '連線',
  'sshConfigAuth': '認證',
  'sshConfigSecurity': '安全',
  'sshConfigPerformance': '效能',
  'sshConfigHostPattern': '主機模式',
  'sshConfigHostPatternHint': '例如 *, myserver, 192.168.1.*',
  'sshConfigServerAliveInterval': '伺服器存活間隔（秒）',
  'sshConfigServerAliveCountMax': '伺服器存活最大次數',
  'sshConfigConnectTimeout': '連線逾時（秒）',
  'sshConfigConnectionAttempts': '連線嘗試次數',
  'sshConfigIdentityFile': '金鑰檔案',
  'sshConfigPreferredAuth': '偏好認證方式',
  'sshConfigStrictHostKey': '嚴格主機金鑰檢查',
  'sshConfigCompression': '壓縮',
  'sshConfigForwardAgent': '轉發代理',
  'sshConfigTcpKeepAlive': 'TCP 保活',
  'sshConfigApplyKeepAlive': '套用保活預設值',
  'sshConfigApplyKeepAliveDesc':
      '設定 ServerAliveInterval=30, ServerAliveCountMax=3',
  'sshConfigNoFile': '未找到 SSH 設定檔',
  'sshConfigCreateNew': '建立設定檔',

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

  // 鍵盤與命令
  'keyEsc': 'ESC',
  'keyTab': 'TAB',
  'keyCtrl': 'CTRL',
  'keyAlt': 'ALT',
  'keyHome': 'HOME',
  'keyEnd': 'END',
  'keyPgUp': '上翻',
  'keyPgDn': '下翻',
  'keyIns': '插入',
  'keyDel': '刪除',
  'keyEnter': 'Enter',
  'keyBackspace': '退格',
  'categorySymbols': '符號',
  'categoryFKeys': 'F鍵',
  'categoryCommands': '命令',
  'categoryNav': '導航',
  'categoryTermux': 'Termux',

  // 檔案管理員
  'fileManager': '檔案管理員',
  'openFile': '開啟檔案',
  'editFile': '編輯檔案',
  'fileInfo': '檔案資訊',
  'fileName': '名稱',
  'fileSize': '大小',
  'modifiedDate': '修改日期',
  'emptyDirectory': '空目錄',
  'back': '返回',
  'home': '主目錄',
  'refresh': '重新整理',
  'storageDirectories': '儲存位置',
  'retry': '重試',
  'openCurrentDirectory': '開啟目前目錄',
  'newFolder': '新建資料夾',
  'enterFolderName': '輸入資料夾名稱',
  'hideHiddenFiles': '隱藏檔案',
  'showHiddenFiles': '顯示隱藏檔案',
  'openInSystem': '在系統開啟',
  'goBackHistory': '返回上一個位置',
};
