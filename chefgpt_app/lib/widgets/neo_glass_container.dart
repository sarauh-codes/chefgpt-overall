import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NeoGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? borderColor;

  const NeoGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.blur = 15.0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: AppColors.glassGradient,
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
