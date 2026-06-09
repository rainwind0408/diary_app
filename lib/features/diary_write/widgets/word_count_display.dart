import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';

class WordCountDisplay extends StatelessWidget {
  final int count;

  const WordCountDisplay({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      '字数: $count',
      style: AppTextStyles.pageNumber,
    );
  }
}
