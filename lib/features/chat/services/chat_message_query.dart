/// 会话消息上的查询。
///
/// 纯 Dart（只依赖 data 层与业务模型），便于在纯 Dart VM 里单测 ——
/// 这些逻辑一旦错了，表现是「AI 照着错的图去画」，很难从界面看出来。
library;

import '../../../data/models/chat_message_record.dart';
import '../models/chat_attachment.dart';

class ChatMessageQuery {
  ChatMessageQuery._();

  /// 会话里**最近一张用户发的图片**的路径；没有就返回 null。
  ///
  /// 只认 `user` 消息：AI 自己生成的图不算「用户的参考图」，否则
  /// 「照着我那张再画一张」会变成拿上一张 AI 图去图生图，越走越偏。
  ///
  /// 倒着找，最新的优先 —— 用户刚发的那张才是他想参考的。
  static String? latestUserImagePath(List<ChatMessageRecord> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role != ChatMessageRecord.roleUser) continue;
      for (final a in ChatAttachment.decodeList(m.attachmentsJson)) {
        if (a.isImage) return a.path;
      }
    }
    return null;
  }
}
