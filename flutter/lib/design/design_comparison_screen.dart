import 'package:flutter/cupertino.dart';

/// 视觉对比工具 - 展示改进前后的设计效果
class DesignComparisonScreen extends StatefulWidget {
  const DesignComparisonScreen({super.key});

  @override
  State<DesignComparisonScreen> createState() => _DesignComparisonScreenState();
}

class _DesignComparisonScreenState extends State<DesignComparisonScreen> {
  int _selectedMode = 0; // 0: 对比, 1: 改进后, 2: 改进前

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('设计对比'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('切换'),
          onPressed: () {
            setState(() {
              _selectedMode = (_selectedMode + 1) % 3;
            });
          },
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeLabel(),
              const SizedBox(height: 24),
              _buildDemoCard(),
              const SizedBox(height: 32),
              _buildDetailsTable(),
              const SizedBox(height: 32),
              _buildComparisonGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeLabel() {
    final labels = ['左改进前 右改进后', '改进后版本', '改进前版本'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        labels[_selectedMode],
        style: const TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDemoCard() {
    if (_selectedMode == 0) {
      return Row(
        children: [
          Expanded(child: _buildBeforeCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildAfterCard()),
        ],
      );
    }
    if (_selectedMode == 1) {
      return _buildAfterCard();
    }
    return _buildBeforeCard();
  }

  Widget _buildBeforeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '改进前',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF189840).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF189840).withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '下一节课',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF189840),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '高等数学（A）',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '09:00-11:00\n教室 A404',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAfterCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '改进后',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF189840).withValues(alpha: 0.05),
                const Color(0xFF189840).withValues(alpha: 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF189840).withValues(alpha: 0.12),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF189840).withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF189840).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '下一节课',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF189840),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '高等数学（A）',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '09:00-11:00\n教室 A404',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  color: CupertinoColors.secondaryLabel,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTable() {
    const headers = ['设计元素', '改进前', '改进后'];
    final data = [
      ['标题字号', '20px', '18px'],
      ['标题粗度', 'w600', 'w700'],
      ['标题间距', '无', '-0.3'],
      ['副标题字号', '13px', '13px'],
      ['副标题间距', '无', '-0.1'],
      ['状态样式', '纯文本', '徽章+背景'],
      ['卡片背景', '纯色 8%', '渐变 5→1%'],
      ['边框宽度', '1.0pt', '0.8pt'],
      ['边框透明度', '18%', '12%'],
      ['阴影', '无', 'blur 6pt'],
      ['交互反馈', '无', '97% scale'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '详细对比表',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.separator, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildTableRow(headers, isHeader: true),
              ...data.map((row) => _buildTableRow(row)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader
            ? CupertinoColors.systemFill
            : CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final flex = e.key == 0 ? 2 : 1;
          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                  color: isHeader
                      ? CupertinoColors.label
                      : CupertinoColors.secondaryLabel,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComparisonGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '关键改进点',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildComparisonItem(
          '1. 排版精致化',
          'letter-spacing (-0.3, -0.2, -0.1)\n字号分层更清晰\n粗度从 w600 到 w700',
          colorValue: 0xFF189840,
        ),
        const SizedBox(height: 12),
        _buildComparisonItem(
          '2. 状态徽章化',
          '纯文本 → 背景+圆角\n12% 彩色背景\n明确的视觉分组',
          colorValue: 0xFF189840,
        ),
        const SizedBox(height: 12),
        _buildComparisonItem(
          '3. 卡片立体化',
          '纯色 → 渐变背景\n添加精细阴影 (blur 6)\n边框更细致 (0.8pt)',
          colorValue: 0xFF189840,
        ),
        const SizedBox(height: 12),
        _buildComparisonItem(
          '4. 交互反馈',
          '无动画 → 97% scale\n+ 70% opacity\n120ms snappy',
          colorValue: 0xFF189840,
        ),
      ],
    );
  }

  Widget _buildComparisonItem(
    String title,
    String description, {
    required int colorValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(colorValue).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(colorValue).withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
