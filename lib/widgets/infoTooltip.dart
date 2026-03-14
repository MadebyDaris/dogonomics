import 'package:flutter/material.dart';
import 'package:Dogonomics/utils/constant.dart';

/// Interactive information tooltip widget that shows educational content
class InfoTooltip extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const InfoTooltip({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: COLOR_INFO, size: 20),
      onPressed: () => _showInfoDialog(context),
      tooltip: 'Learn more',
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CARD_BACKGROUND,
        title: Row(
          children: [
            Icon(icon, color: COLOR_INFO),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: HEADING_MEDIUM,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: BODY_PRIMARY.copyWith(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: BODY_PRIMARY.copyWith(
                color: ACCENT_GREEN,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable info card for detailed explanations
class InfoCard extends StatefulWidget {
  final String title;
  final String summary;
  final String? detailedInfo;
  final IconData icon;
  final Color? iconColor;

  const InfoCard({
    Key? key,
    required this.title,
    required this.summary,
    this.detailedInfo,
    this.icon = Icons.lightbulb_outline,
    this.iconColor,
  }) : super(key: key);

  @override
  State<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND_ELEVATED,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.detailedInfo != null
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (widget.iconColor ?? COLOR_INFO).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor ?? COLOR_INFO,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: HEADING_SMALL),
                        const SizedBox(height: 4),
                        Text(
                          widget.summary,
                          style: BODY_SECONDARY,
                          maxLines: _isExpanded ? null : 2,
                          overflow: _isExpanded ? null : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.detailedInfo != null)
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: TEXT_SECONDARY,
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded && widget.detailedInfo != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: APP_BACKGROUND,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                widget.detailedInfo!,
                style: BODY_PRIMARY.copyWith(height: 1.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Quick tip banner
class QuickTipBanner extends StatelessWidget {
  final String tip;
  final IconData icon;
  final Color color;

  const QuickTipBanner({
    Key? key,
    required this.tip,
    this.icon = Icons.tips_and_updates,
    this.color = COLOR_WARNING,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: BODY_SECONDARY.copyWith(color: TEXT_PRIMARY),
            ),
          ),
        ],
      ),
    );
  }
}
