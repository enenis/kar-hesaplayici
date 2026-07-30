import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';

/// İçeriği ekran boyutuna göre ortalar ve maksimum genişlik uygular.
/// Böylece tabletlerde/foldable'larda içerik aşırı gerilmez.
class ResponsiveLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.contentMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}

/// Yan yana iki kart göstermek için (tablette 2 sütun, telefonda 1 sütun).
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveRow({super.key, required this.children, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= ResponsiveHelper.mobileBreakpoint;
        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
