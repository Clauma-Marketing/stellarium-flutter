import 'package:flutter/material.dart';

import '../utils/sun_times.dart';

/// A simple time slider using Flutter's default Material Slider.
/// - Slider range: 0 to 1439 (minutes)
class TimeSlider extends StatefulWidget {
  /// Current value from 0 to 1439 (minutes)
  final int value;

  /// Called when the value changes
  final ValueChanged<int> onChanged;

  /// Called when the user starts selecting a new value
  final ValueChanged<double>? onChangeStart;

  /// Called when the user is done selecting a new value
  final ValueChanged<double>? onChangeEnd;

  /// Sun times (kept for API compatibility)
  final SunTimes sunTimes;

  const TimeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    required this.sunTimes,
  });

  @override
  State<TimeSlider> createState() => _TimeSliderState();
}

class _TimeSliderState extends State<TimeSlider> {
  // Use local state to track the slider value during dragging
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    // Use drag value if actively dragging, otherwise use widget value
    final displayValue = _dragValue ?? widget.value.toDouble();

    return Slider(
      value: displayValue.clamp(0, 1439),
      min: 0,
      max: 1439,
      onChanged: (newValue) {
        setState(() {
          _dragValue = newValue;
        });
        widget.onChanged(newValue.round());
      },
      onChangeStart: (value) {
        setState(() {
          _dragValue = value;
        });
        widget.onChangeStart?.call(value);
      },
      onChangeEnd: (value) {
        setState(() {
          _dragValue = null;
        });
        widget.onChangeEnd?.call(value);
      },
    );
  }
}
