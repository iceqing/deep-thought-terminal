import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

/// Persisted session data for restoring terminal tabs on app restart.
class PersistedSession {
  final String id;
  final String title;
  final bool isSshSession;
  final String bufferContent;
  final String? workingDirectory;

  PersistedSession({
    required this.id,
    required this.title,
    required this.isSshSession,
    required this.bufferContent,
    this.workingDirectory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isSshSession': isSshSession,
        'bufferContent': bufferContent,
        'workingDirectory': workingDirectory,
      };

  factory PersistedSession.fromJson(Map<String, dynamic> json) {
    return PersistedSession(
      id: json['id'] as String,
      title: json['title'] as String,
      isSshSession: json['isSshSession'] as bool? ?? false,
      bufferContent: json['bufferContent'] as String? ?? '',
      workingDirectory: json['workingDirectory'] as String?,
    );
  }
}

/// Persisted state: list of sessions + which tab was active.
class PersistedState {
  final List<PersistedSession> sessions;
  final int activeIndex;

  PersistedState({required this.sessions, required this.activeIndex});

  Map<String, dynamic> toJson() => {
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'activeIndex': activeIndex,
      };

  factory PersistedState.fromJson(Map<String, dynamic> json) {
    final list = (json['sessions'] as List?)
            ?.map((e) => PersistedSession.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PersistedState(
      sessions: list,
      activeIndex: json['activeIndex'] as int? ?? 0,
    );
  }
}

/// Service to save/restore terminal sessions across app restarts.
class SessionPersistenceService {
  SessionPersistenceService._();
  static final instance = SessionPersistenceService._();

  String get _filePath {
    final configDir = TermuxConstants.termuxConfigDir;
    return '$configDir/sessions.json';
  }

  /// Save session state to disk.
  Future<void> save(PersistedState state) async {
    try {
      final file = File(_filePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final json = jsonEncode(state.toJson());
      await file.writeAsString(json);
      debugPrint('[SessionPersistence] Saved ${state.sessions.length} sessions');
    } catch (e) {
      debugPrint('[SessionPersistence] Save error: $e');
    }
  }

  /// Load session state from disk.
  Future<PersistedState?> load() async {
    try {
      final file = File(_filePath);
      if (!file.existsSync()) return null;
      final json = await file.readAsString();
      if (json.trim().isEmpty) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      final state = PersistedState.fromJson(data);
      debugPrint(
          '[SessionPersistence] Loaded ${state.sessions.length} sessions');
      return state;
    } catch (e) {
      debugPrint('[SessionPersistence] Load error: $e');
      return null;
    }
  }

  /// Clear saved state (e.g. after successful restore).
  Future<void> clear() async {
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[SessionPersistence] Clear error: $e');
    }
  }
}
