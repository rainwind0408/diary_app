import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import '../services/diary_mcp.dart';
import '../../../data/repositories/diary_repository.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final LlmService _llmService = LlmService();
  late final DiaryMcpServer _mcpServer;
  bool _isLoading = false;
  String? _error;

  ChatProvider() {
    _mcpServer = DiaryMcpServer(DiaryRepository());
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearMessages() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _error = null;
    _messages.add(ChatMessage(role: 'user', content: content.trim()));
    _isLoading = true;
    notifyListeners();

    try {
      await _processWithTools();
    } catch (e) {
      _error = e.toString();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '抱歉，发生了错误：${e.toString()}',
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _processWithTools({int depth = 0}) async {
    if (depth > 5) {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '工具调用次数过多，请尝试简化问题。',
      ));
      return;
    }

    final response = await _llmService.chat(
      messages: _messages,
      tools: _mcpServer.getToolDefinitions(),
    );

    if (response.toolCalls == null || response.toolCalls!.isEmpty) {
      _messages.add(response);
      return;
    }

    _messages.add(response);
    notifyListeners();

    for (final toolCall in response.toolCalls!) {
      final result = await _mcpServer.execute(
        toolCall.name,
        toolCall.arguments,
      );
      _messages.add(ChatMessage(
        role: 'tool',
        content: result,
        toolCallId: toolCall.id,
        toolName: toolCall.name,
      ));
    }
    notifyListeners();

    await _processWithTools(depth: depth + 1);
  }
}
