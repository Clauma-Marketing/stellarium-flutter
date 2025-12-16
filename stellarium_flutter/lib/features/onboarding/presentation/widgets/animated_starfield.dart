import 'package:flutter/material.dart';

/// Night sky background for onboarding screens
class AnimatedStarfield extends StatelessWidget {
  final int starCount; // kept for API compatibility, but unused
  final Widget? child;

  const AnimatedStarfield({
    super.key,
    this.starCount = 80,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background_nightsky2.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
