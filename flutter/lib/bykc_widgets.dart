import 'package:flutter/cupertino.dart';

class BykcStatisticsCard extends StatelessWidget {
  const BykcStatisticsCard({super.key, required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final required = entry['required'] as int;
    final completed = entry['completed'] as int;
    final complete = required > 0 && completed >= required;
    final status = required == 0
        ? '本项暂无要求'
        : complete
        ? '已完成'
        : '还差 ${required - completed} 项';
    final color = complete
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Semantics(
        label:
            '${entry['category']}，${entry['subcategory']}，已完成 $completed 项，应完成 $required 项，$status',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    entry['subcategory'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completed / $required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: complete ? color : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              if (required > 0) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (completed / required).clamp(0.0, 1.0),
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BykcLabel extends StatelessWidget {
  const BykcLabel({super.key, required this.text, this.positive = false});
  final String text;
  final bool positive;
  @override
  Widget build(BuildContext context) {
    final color = positive
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: positive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class BykcMetadata extends StatelessWidget {
  const BykcMetadata({
    super.key,
    required this.icon,
    required this.text,
    this.prominent = false,
    this.auxiliary = false,
  });
  final IconData icon;
  final String text;
  final bool prominent, auxiliary;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: auxiliary ? 12 : 14,
            fontWeight: prominent ? FontWeight.w500 : FontWeight.w400,
            color: prominent
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ],
  );
}
