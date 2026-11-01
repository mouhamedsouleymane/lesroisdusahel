import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class CurvedNavItem {
  final IconData icon;
  final String label;
  final int badgeCount;

  const CurvedNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
}

class CurvedFloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedNavItem> items;

  const CurvedFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<CurvedFloatingNavBar> createState() => _CurvedFloatingNavBarState();
}

class _CurvedFloatingNavBarState extends State<CurvedFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _targetIndex = 0;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    ));
  }

  @override
  void didUpdateWidget(CurvedFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      final from = _animation.value;
      final to = widget.currentIndex.toDouble();
      _animation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutCubicEmphasized,
        ),
      );
      _targetIndex = widget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 66.0;
    const double circleRadius = 24.0; // diamètre 48
    const double totalHeight = barHeight + 18.0;
    const double horizontalPadding = 12.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double animatedIndex = _animation.value;

          return SizedBox(
            height: totalHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final double usableWidth = width - (horizontalPadding * 2);
                final double itemWidth = usableWidth / widget.items.length;
                final double activeCenterX =
                    horizontalPadding + (animatedIndex + 0.5) * itemWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Fond incurvé avec encoche fluide (Dock violet impérial sombre)
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: CustomPaint(
                        painter: _CurvedBarPainter(
                          activeCenterX: activeCenterX,
                          backgroundColor: const Color(0xFF260438),
                          notchRadius: 29.0,
                          notchDepth: 18.0,
                        ),
                      ),
                    ),

                    // Bulle flottante active ambre / or avec ombre portée
                    Positioned(
                      left: activeCenterX - circleRadius,
                      top: 0,
                      child: Container(
                        width: circleRadius * 2,
                        height: circleRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentGold,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGold.withValues(alpha: 0.50),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              widget.items[_targetIndex].icon,
                              key: ValueKey('active_icon_$_targetIndex'),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Rangée des boutons avec icônes et libellés (noms des boutons)
                    Positioned(
                      top: 14,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          children: List.generate(widget.items.length, (index) {
                            final isSelected = index == widget.currentIndex;
                            final item = widget.items[index];

                            return Expanded(
                              child: InkWell(
                                onTap: () => widget.onTap(index),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 7, top: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (!isSelected) ...[
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Icon(
                                              item.icon,
                                              color: Colors.white.withValues(alpha: 0.85),
                                              size: 21,
                                            ),
                                            if (item.badgeCount > 0)
                                              Positioned(
                                                right: -8,
                                                top: -5,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 4.5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: const Color(0xFF260438),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.badgeCount > 99
                                                        ? '99+'
                                                        : '${item.badgeCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                      ],
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppTheme.accentGoldLight
                                              : Colors.white.withValues(alpha: 0.85),
                                          fontSize: 10.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CurvedBarPainter extends CustomPainter {
  final double activeCenterX;
  final Color backgroundColor;
  final double notchRadius;
  final double notchDepth;

  const _CurvedBarPainter({
    required this.activeCenterX,
    required this.backgroundColor,
    required this.notchRadius,
    required this.notchDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Ombre portée sous le dock
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    const double cornerRadius = 22.0;
    final double cx = activeCenterX;
    final double nr = notchRadius;
    final double nd = notchDepth;

    final path = Path();
    // Coin supérieur gauche
    path.moveTo(0, cornerRadius);
    path.arcToPoint(
      const Offset(cornerRadius, 0),
      radius: const Radius.circular(cornerRadius),
    );

    // Bord supérieur menant à l'encoche
    final double notchStart = (cx - nr).clamp(cornerRadius, size.width - cornerRadius);
    final double notchEnd = (cx + nr).clamp(cornerRadius, size.width - cornerRadius);

    path.lineTo(notchStart, 0);

    // Encoche incurvée fluide (double cubique Bézier)
    path.cubicTo(
      cx - nr * 0.55, 0,
      cx - nr * 0.45, nd,
      cx, nd,
    );
    path.cubicTo(
      cx + nr * 0.45, nd,
      cx + nr * 0.55, 0,
      notchEnd, 0,
    );

    // Bord supérieur vers le coin supérieur droit
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );

    // Bord droit
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: const Radius.circular(cornerRadius),
    );

    // Bord inférieur
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );

    // Bord gauche
    path.lineTo(0, cornerRadius);
    path.close();

    // Dessin ombre + corps du dock
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedBarPainter oldDelegate) {
    return oldDelegate.activeCenterX != activeCenterX ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
