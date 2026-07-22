import 'package:flutter/material.dart';

import '../models/app_domain.dart';
import 'tap_feedback.dart';

/// Domain header that expands/collapses children.
/// Collapsed: domain name + count only. Google-style, one pattern for Likes + Me.
class ExpandableDomainSection extends StatefulWidget {
  const ExpandableDomainSection({
    required this.domain,
    required this.count,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
    this.sectionKey,
    super.key,
  });

  final DomainPolicy domain;
  final int count;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Key? sectionKey;

  @override
  State<ExpandableDomainSection> createState() =>
      _ExpandableDomainSectionState();
}

class _ExpandableDomainSectionState extends State<ExpandableDomainSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final policy = widget.domain;
    return Padding(
      key: widget.sectionKey,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInkWell(
            key: Key('domain_section_header_${policy.id.name}'),
            color: policy.softColor,
            onTap: () => setState(() => _expanded = !_expanded),
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: .75),
                  child: Icon(widget.icon, color: policy.color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    policy.label,
                    style: TextStyle(
                      color: policy.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: policy.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: policy.color,
                  size: 28,
                ),
              ],
            ),
          ),
          if (_expanded) ...[const SizedBox(height: 8), ...widget.children],
        ],
      ),
    );
  }
}
