import 'package:flutter/cupertino.dart';

/// 独立的 Demo 页面 - 展示 TodayActionRow 的三个版本
class TodayActionRowDemo extends StatelessWidget {
  const TodayActionRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('TodayActionRow 改进演示'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '1️⃣ 改进前版本',
                subtitle: '原始设计：平面、缺乏反馈',
                child: _buildBeforeCard(),
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: '2️⃣ 改进后版本 (Emphasized)',
                subtitle: '精致、有深度、有交互反馈',
                child: _buildAfterEmphasizedCard(),
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: '3️⃣ 改进后版本 (Normal)',
                subtitle: '微妙的分隔，保持简洁',
                child: _buildAfterNormalCard(),
              ),
              const SizedBox(height: 32),
              _buildComparisonTable(),
              const SizedBox(height: 32),
              _buildFeatureHighlights(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildBeforeCard() {
    return Container(
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
    );
  }

  Widget _buildAfterEmphasizedCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF189840).withValues(alpha: 0.06),
            const Color(0xFF189840).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF189840).withValues(alpha: 0.14),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF189840).withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF189840).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '下一节课',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF189840),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '高等数学（A）',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.15,
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
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterNormalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF189840).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        '下一节课',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF189840),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '高等数学（A）',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        height: 1.15,
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
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '参数对比',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.separator, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildTableHeader(['参数', '改进前', '改进后']),
              _buildTableRow(['标题字号', '20px', '19px']),
              _buildTableRow(['标题粗度', 'w600', 'w700']),
              _buildTableRow(['标题间距', '无', '-0.2']),
              _buildTableRow(['徽章背景', '12%', '18%']),
              _buildTableRow(['副标题 height', '1.5', '1.4']),
              _buildTableRow(['阴影 blur', '6pt', '4pt']),
              _buildTableRow(['边框宽度', '1.0pt', '0.8pt']),
              _buildTableRow(['Chevron', '14px', '16px']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> cells) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemFill,
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
              padding: const EdgeInsets.all(10),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(List<String> cells) {
    return Container(
      decoration: BoxDecoration(
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
              padding: const EdgeInsets.all(10),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✨ 关键改进',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildHighlightItem(
          '排版精致化',
          'letter-spacing 控制 (-0.3, -0.2, -0.1)\n字号和粗度分层更清晰',
        ),
        const SizedBox(height: 8),
        _buildHighlightItem('状态徽章化', '纯文本 → 彩色背景标签\n18% 彩色背景，更醒目'),
        const SizedBox(height: 8),
        _buildHighlightItem('卡片立体化', '渐变背景 (垂直) + 4pt 精细阴影\n边框优化为 0.8pt，更精致'),
        const SizedBox(height: 8),
        _buildHighlightItem('交互反馈', '按下时 97% 缩放 + 70% 透明度\n120ms 流畅动画'),
        const SizedBox(height: 8),
        _buildHighlightItem('Normal 分隔', '微妙的底部分隔线 (0.5pt)\n保持简洁的同时增加分层'),
      ],
    );
  }

  Widget _buildHighlightItem(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF189840).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF189840).withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
              height: 1.5,
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );
  }
}
