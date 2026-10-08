import 'package:flutter/foundation.dart';

import '../../../data/models/chat_message_record.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/repositories/chat_session_repository.dart';
import '../models/chat_attachment.dart';
import '../services/attachment_store.dart';

/// AI 助手会话状态管理：会话列表、当前会话、消息列表。
///
/// P0 只提供数据能力（持久化 + 切换 + 增删改），不改动任何界面。
class ChatSessionProvider extends ChangeNotifier {
  final ChatSessionRepository _repository = ChatSessionRepository();

  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessageRecord> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get currentSession => _currentSession;
  int? get currentSessionId => _currentSession?.id;
  List<ChatMessageRecord> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSessions => _sessions.isNotEmpty;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // 加载
  // ─────────────────────────────────────────────

  /// 加载会话列表；若当前会话不存在则自动选中最近一个
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessions = await _repository.getSessions();
      _error = null;

      final currentId = _currentSession?.id;
      final stillExists =
          currentId != null && _sessions.any((s) => s.id == currentId);

      if (!stillExists) {
        if (_sessions.isNotEmpty) {
          await _loadMessagesOf(_sessions.first.id!);
        } else {
          _currentSession = null;
          _messages = [];
        }
      } else {
        // 刷新当前会话的元信息（标题/计数可能已变）
        for (final s in _sessions) {
          if (s.id == currentId) {
            _currentSession = s;
            break;
          }
        }
      }
    } catch (e) {
      _error = '加载会话失败：$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 确保存在一个会话（没有就新建），返回该会话
  Future<ChatSession> ensureSession({
    String providerId = '',
    String model = '',
  }) async {
    final current = _currentSession;
    if (current != null && current.id != null) return current;
    if (_sessions.isEmpty) {
      await loadSessions();
    }
    if (_sessions.isNotEmpty) {
      await switchSession(_sessions.first.id!);
      return _currentSession!;
    }
    return createSession(providerId: providerId, model: model);
  }

  // ─────────────────────────────────────────────
  // 会话操作
  // ─────────────────────────────────────────────

  Future<ChatSession> createSession({
    String? title,
    String providerId = '',
    String model = '',
  }) async {
    final session = await _repository.createSession(
      title: title,
      providerId: providerId,
      model: model,
    );
    _sessions = await _repository.getSessions();
    await _loadMessagesOf(session.id!);
    notifyListeners();
    return session;
  }

  Future<void> switchSession(int sessionId) async {
    if (_currentSession?.id == sessionId) return;
    await _loadMessagesOf(sessionId);
    notifyListeners();
  }

  Future<void> renameSession(int sessionId, String title) async {
    await _repository.renameSession(sessionId, title);
    await _reloadSessionsPreservingCurrent();
    notifyListeners();
  }

  Future<void> togglePin(int sessionId) async {
    final session = _findSession(sessionId);
    if (session == null) return;
    await _repository.pinSession(sessionId, !session.isPinned);
    await _reloadSessionsPreservingCurrent();
    notifyListeners();
  }

  /// 删除会话；若删的是当前会话，自动切到剩下的第一个
  Future<void> deleteSession(int sessionId) async {
    await _repository.deleteSession(sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
      _messages = [];
    }
    _sessions = await _repository.getSessions();
    if (_currentSession == null && _sessions.isNotEmpty) {
      await _loadMessagesOf(_sessions.first.id!);
    }
    notifyListeners();
    await sweepOrphanAttachments();
  }

  Future<void> clearAllSessions() async {
    await _repository.clearAllSessions();
    _sessions = [];
    _currentSession = null;
    _messages = [];
    notifyListeners();
    await sweepOrphanAttachments();
  }

  /// 清理不再被任何消息引用的附件文件，返回删除数量。
  ///
  /// 删除会话 / 清空会话后调用，避免磁盘上堆积孤儿附件。
  /// 失败不抛异常 —— 清理是尽力而为，不该影响主流程。
  Future<int> sweepOrphanAttachments() async {
    try {
      final raws = await _repository.getAllAttachmentsJson();
      final referenced = <String>{};
      for (final raw in raws) {
        for (final a in ChatAttachment.decodeList(raw)) {
          referenced.add(a.path);
        }
      }
      return await AttachmentStore.sweepOrphans(referenced);
    } catch (_) {
      return 0;
    }
  }

  // ─────────────────────────────────────────────
  // 消息操作
  // ─────────────────────────────────────────────

  /// 追加一条消息并持久化，返回带 id 的记录。
  ///
  /// 若当前会话仍是默认标题且这是首条用户消息，会自动生成标题。
  Future<ChatMessageRecord> appendMessage(ChatMessageRecord message) async {
    final id = await _repository.appendMessage(message);
    final saved = message.copyWith(id: id);

    if (_currentSession?.id == message.sessionId) {
      _messages = [..._messages, saved];

      final session = _currentSession;
      if (session != null &&
          session.title == ChatSession.defaultTitle &&
          message.isUser &&
          message.content.trim().isNotEmpty) {
        await _repository.renameSession(
          message.sessionId,
          ChatSession.titleFromMessage(message.content),
        );
      }
    }

    // 工具消息的 content 是原始 JSON，不该出现在会话列表的预览里
    await _repository.touchSession(
      message.sessionId,
      lastMessage: message.isTool ? null : message.content,
    );
    await _reloadSessionsPreservingCurrent();
    notifyListeners();
    return saved;
  }

  Future<void> updateMessageContent(int messageId, String content) async {
    await _repository.updateMessageContent(messageId, content);
    _replaceMessageInMemory(messageId, (m) => m.copyWith(content: content));
    notifyListeners();
  }

  Future<void> updateMessageStatus(int messageId, String status) async {
    await _repository.updateMessageStatus(messageId, status);
    _replaceMessageInMemory(messageId, (m) => m.copyWith(status: status));
    notifyListeners();
  }

  Future<void> updateMessageContentAndStatus(
    int messageId,
    String content,
    String status,
  ) async {
    await _repository.updateMessageContentAndStatus(messageId, content, status);
    _replaceMessageInMemory(
      messageId,
      (m) => m.copyWith(content: content, status: status),
    );
    notifyListeners();
  }

  Future<void> deleteMessage(int messageId) async {
    await _repository.deleteMessage(messageId);
    _messages = _messages.where((m) => m.id != messageId).toList();
    final sessionId = _currentSession?.id;
    if (sessionId != null) {
      await _repository.touchSession(sessionId);
      await _reloadSessionsPreservingCurrent();
    }
    notifyListeners();
    await sweepOrphanAttachments();
  }

  /// 删除某条消息之后的全部消息（「重新生成」用）
  Future<void> deleteMessagesAfter(int messageId) async {
    final sessionId = _currentSession?.id;
    if (sessionId == null) return;
    await _repository.deleteMessagesAfterId(sessionId, messageId);
    _messages = await _repository.getMessages(sessionId);
    await _repository.touchSession(sessionId);
    await _reloadSessionsPreservingCurrent();
    notifyListeners();
  }

  /// 当前会话中最后一条用户消息（没有则 null）
  ChatMessageRecord? get lastUserMessage {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) return _messages[i];
    }
    return null;
  }

  /// 读取某个会话的消息，**不改变当前会话**。
  ///
  /// 专供导出用：从会话列表里导出一段**不是当前**的会话时，不该顺手把用户
  /// 切到那个会话去（他只想导个文件）。
  Future<List<ChatMessageRecord>> messagesOf(int sessionId) async {
    if (sessionId == _currentSession?.id) return _messages;
    return _repository.getMessages(sessionId);
  }

  // ─────────────────────────────────────────────
  // 内部
  // ─────────────────────────────────────────────

  Future<void> _loadMessagesOf(int sessionId) async {
    try {
      _messages = await _repository.getMessages(sessionId);
      _currentSession = _findSession(sessionId) ??
          await _repository.getSessionById(sessionId);
      _error = null;
    } catch (e) {
      _error = '加载消息失败：$e';
      _messages = [];
    }
  }

  ChatSession? _findSession(int id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _reloadSessionsPreservingCurrent() async {
    _sessions = await _repository.getSessions();
    final currentId = _currentSession?.id;
    if (currentId == null) return;
    final refreshed = _findSession(currentId);
    if (refreshed != null) _currentSession = refreshed;
  }

  void _replaceMessageInMemory(
    int messageId,
    ChatMessageRecord Function(ChatMessageRecord) transform,
  ) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    _messages = [..._messages]..[idx] = transform(_messages[idx]);
  }
}
