import 'dart:math';

import 'package:flutter/material.dart';

/// A star in the animated starfield
class _Star {
  final double x; // 0.0 to 1.0 relative position
  final double y; // 0.0 to 1.0 relative position
  final double size;
  final int twinkleDuration; // milliseconds
  final int initialDelay; // milliseconds

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleDuration,
    required this.initialDelay,
  });
}

/// Animated starfield background with twinkling stars
class AnimatedStarfield extends StatefulWidget {
  final int starCount;
  final Widget? child;

  const AnimatedStarfield({
    super.key,
    this.starCount = 80,
    this.child,
  });

  @override
  State<AnimatedStarfield> createState() => _AnimatedStarfieldState();
}

class _AnimatedStarfieldState extends State<AnimatedStarfield>
    with TickerProviderStateMixin {
  late List<_Star> _stars;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateStars();
  }

  void _generateStars() {
    _stars = List.generate(widget.starCount, (index) {
      return _Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 0.5 + _random.nextDouble() * 2.0,
        twinkleDuration: 1000 + _random.nextInt(2000),
        initialDelay: _random.nextInt(2000),
      );
    });

    _controllers = [];
    _animations = [];

    for (final star in _stars) {
      final controller = AnimationController(
        duration: Duration(milliseconds: star.twinkleDuration),
        vsync: this,
      );

      final animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );

      _controllers.add(controller);
      _animations.add(animation);

      // Start animation with initial delay
      Future.delayed(Duration(milliseconds: star.initialDelay), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0a1628), // Very dark blue
            Color(0xFF1a237e), // Darker blue
            Color(0xFF311b92), // Deep purple
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Stars layer
          ...List.generate(_stars.length, (index) {
            final star = _stars[index];
            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Positioned(
                  left: star.x * MediaQuery.of(context).size.width,
                  top: star.y * MediaQuery.of(context).size.height,
                  child: Container(
                    width: star.size,
                    height: star.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: _animations[index].value),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: _animations[index].value * 0.5),
                          blurRadius: 2,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          // Child content
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
