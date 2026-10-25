import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/theme/motion.dart';

/// One-shot animation helpers (typography & motion pass). Looping helpers
/// gate on reduce-motion AND on the FLUTTER_TEST environment so tests can
/// pumpAndSettle without hanging.

/// True inside `flutter test`. `bool.fromEnvironment('FLUTTER_TEST')` is
/// not set by every test toolchain, so detect the test binding by name
/// instead (repeating controllers would hang pumpAndSettle).
bool get _underTest => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

/// Rebuilds its [child] animation from zero whenever [key] changes —
/// one-shot emphasis (pulse on cal_id change, shake on error 3, …).
class KeyedOneShot extends StatelessWidget {
  const KeyedOneShot({
    super.key,
    required this.trigger,
    required this.builder,
  });

  /// When this value changes, the animation replays.
  final Object? trigger;

  final Widget Function(Animation<double> t, BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final motion = TalkhimikMotion.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: motion.resolve(context, motion.quick),
      curve: motion.enterCurve,
      builder: (context, t, _) => builder(AlwaysStoppedAnimation(t), context),
    );
  }
}

/// Fade + slight rise on mount (bubbles, session cards, empty states).
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.offset = 12});

  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final motion = TalkhimikMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.resolve(context, motion.quick),
      curve: motion.enterCurve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Shrinks to 97 % while pressed (microinteraction for pill buttons).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final motion = TalkhimikMotion.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: motion.resolve(context, motion.instant),
        child: widget.child,
      ),
    );
  }
}

/// Fires one selection-click haptic on mount (completion moments: the
/// calibration done screen).
class HapticOnce extends StatefulWidget {
  const HapticOnce({super.key, required this.child});

  final Widget child;

  @override
  State<HapticOnce> createState() => _HapticOnceState();
}

class _HapticOnceState extends State<HapticOnce> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Looping pulse. Static (full size, no controller) under reduce-motion or
/// in tests — a repeating controller would hang pumpAndSettle.
class LoopPulse extends StatefulWidget {
  const LoopPulse({
    super.key,
    required this.child,
    this.scale = 1.12,
    this.pulse = true,
  });

  final Widget child;
  final double scale;

  /// When false the child renders statically (idle dots, tests).
  final bool pulse;

  @override
  State<LoopPulse> createState() => _LoopPulseState();
}

class _LoopPulseState extends State<LoopPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed = widget.pulse &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_underTest;
    if (allowed && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    } else if (!allowed && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: widget.scale).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
