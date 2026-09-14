import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';
import '../services/garden_arranger.dart';
import 'achievement_detail_dialog.dart';
import 'garden_plant.dart';

/// 成长花园
///
/// 把「成就收集」重新隐喻为「植物生长」——[AchievementDefs] 里写作成就的
/// 命名本就是植物语系（萌芽 → 成长 → 茂盛 → 参天 → 巅峰），这里把它兑现为视觉。
///
/// 与普通网格的关键区别：
/// - **不是等大网格，是山坡**：底部宽、顶部窄，形成生长坡度
/// - **已解锁在上层**：越靠下越早解锁，越靠上越晚解锁（视觉上「长得更高」）
/// - **未解锁是剪影**：去色 + 「?」，而不是涂灰了事
class GrowthGarden extends StatelessWidget {
  final List<Achievement> achievements;

  const GrowthGarden({super.key, required this.achievements});

  /// 每行植物数（从上到下），从窄到宽铺成山坡
  ///
  /// 之所以写成一个"容量表"而不是固定 7 行，是为了**按实际数量裁剪**：
  /// 20 个成就铺 7 行会留下大片空洞，所以只保留真正装得下的行数。
  static const List<int> _rowLayout = [2, 2, 3, 3, 5, 5, 8];

  /// 每株植物占的宽度（含间距），用于把容量表换算成实际需要的行数
  static const double _slotWidth = 44;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    // 排序：已解锁的在前（按解锁时间倒序 → 最新的排在数组开头），
    // 未解锁的在后。摆进「山坡」时从下往上填，于是最新的在最底下（刚长出来）。
    final sorted = GardenArranger.arrange(achievements);

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final total = achievements.length;

    // 只保留"装得下"的行：从最宽的行开始往回裁，保证不留大片空洞。
    // 例：20 个成就 → [2,2,3,3,5,5,8] 全部用上刚好 28 位；
    //     但若只有 12 个，则裁到 [2,2,3,5]，少掉空行。
    final layout = _fitLayout(sorted.length);

    // 把成就按行分配：山坡的底部行在前（填满后再往上）
    final rows = <List<Achievement?>>[];
    var cursor = 0;
    for (var i = layout.length - 1; i >= 0; i--) {
      final capacity = layout[i];
      final row = <Achievement?>[];
      for (var j = 0; j < capacity; j++) {
        row.add(cursor < sorted.length ? sorted[cursor++] : null);
      }
      rows.add(row);
    }

    // 计算可用的植物槽宽：卡片内宽 ÷ 最宽行的植物数，避免行溢出
    final cardWidth = MediaQuery.of(context).size.width - 32 - 32;
    final maxPerRow = layout.reduce((a, b) => a > b ? a : b);
    final slotWidth = (cardWidth / maxPerRow).clamp(28.0, _slotWidth);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // 标题 + 进度
          Row(
            children: [
              Text(
                '我的花园',
                style: AppTextStyles.cardTitle.copyWith(
                  color: textColor,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                '已养成 $unlockedCount / $total 株',
                style: TextStyle(fontSize: 12, color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : unlockedCount / total,
              backgroundColor: subtleColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(goldColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 16),

          // 山坡：从上往下渲染，行宽递增
          for (var r = 0; r < rows.length; r++) ...[
            _buildRow(context, rows[r], r, rows.length, isDark, slotWidth),
            const SizedBox(height: 6),
          ],

          // 土壤
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                colors: [
                  AppColors.yellowLight.withValues(alpha: isDark ? 0.10 : 0.55),
                  AppColors.greenLight.withValues(alpha: isDark ? 0.08 : 0.45),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            unlockedCount == 0
                ? '写下第一篇日记，种下第一株幼苗'
                : '继续记录，让花园长得更茂盛',
            style: TextStyle(
              fontSize: 11,
              color: subtleColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 渲染一行植物
  ///
  /// [rowIndex] 从上往下 0 起；[rowCount] 总行数。
  /// 越靠下（rowIndex 越大）的行代表越早解锁的成就，
  /// 因此给它们更高的 [growth]（更成熟、略大）。
  ///
  /// [slotWidth] 由调用方按卡片实际宽度算好，每株固定占这么宽 ——
  /// 用固定槽宽 + `Flexible` 包一层，行永远不会横向溢出。
  Widget _buildRow(
    BuildContext context,
    List<Achievement?> items,
    int rowIndex,
    int rowCount,
    bool isDark,
    double slotWidth,
  ) {
    // 底部行 growth 接近 1.0，顶部行接近 0.3
    final depth = rowCount <= 1 ? 1.0 : rowIndex / (rowCount - 1);
    final rowGrowth = 0.3 + 0.7 * depth;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++)
          Flexible(
            child: SizedBox(
              width: slotWidth,
              child: items[i] == null
                  // 空位：留出与植物等高的坑，保持行的间距节奏
                  ? const SizedBox(height: 48)
                  : GardenPlant(
                      achievement: items[i]!,
                      growth: rowGrowth,
                      // 用行列做相位偏移，避免整片花园同步摇摆
                      phaseOffset: ((rowIndex * 7 + i) % 10) / 10.0,
                      onTap: () => AchievementDetailDialog.show(
                        context,
                        items[i]!,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  /// 从 [_rowLayout] 里裁出刚好装得下 [count] 个成就的行配置
  ///
  /// 思路：行是从宽到窄排列的（底部宽）。若一口气用满 7 行，
  /// 成就少的时候底部会空一大半。所以**逐行累加容量，够用就停**。
  static List<int> _fitLayout(int count) {
    var sum = 0;
    final used = <int>[];
    // _rowLayout 从上（窄）到下（宽），累加时要按"从下往上"的真实使用顺序来算：
    // 底部行先被填满，所以累加顺序是 _rowLayout 的逆序
    for (var i = _rowLayout.length - 1; i >= 0; i--) {
      used.add(_rowLayout[i]);
      sum += _rowLayout[i];
      if (sum >= count) break;
    }
    // used 是"从底到顶"，翻回"从顶到底"以匹配渲染顺序
    return used.reversed.toList();
  }
}
