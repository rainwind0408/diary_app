import 'package:flutter/material.dart';
import '../../../../data/models/diary_entry.dart';
import 'diary_card.dart';
import 'swipe_action_card.dart';

class AnimatedDiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onDeleteRequested;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;
  final bool triggerDismiss;

  const AnimatedDiaryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteRequested,
    this.onLock,
    this.onUnlock,
    this.triggerDismiss = false,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeActionCard(
      triggerDismiss: triggerDismiss,
      onDismissed: onDelete,
      isLocked: entry.isLocked,
      onDelete: onDeleteRequested,
      onLock: onLock,
      onUnlock: onUnlock,
      child: DiaryCard(
        entry: entry,
        onEdit: onEdit,
        onDelete: onDeleteRequested,
        onLock: onLock,
        onUnlock: onUnlock,
      ),
    );
  }
}
