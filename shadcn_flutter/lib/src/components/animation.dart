import 'package:flutter/widgets.dart';

typedef AnimatedChildBuilder<T> = Widget Function(
    BuildContext context, T value, Widget? child);
typedef AnimationBuilder<T> = Widget Function(
    BuildContext context, Animation<T> animation);

class AnimatedValueBuilder<T> extends StatefulWidget {
  final T? initialValue;
  final T value;
  final Duration? duration;
  final Duration Function(T a, T b)? durationBuilder;
  final AnimatedChildBuilder<T>? builder;
  final AnimationBuilder<T>? animationBuilder;
  final void Function(T value)? onEnd;
  final Curve curve;
  final T Function(T a, T b, double t)? lerp;
  final Widget? child;

  const AnimatedValueBuilder({
    Key? key,
    this.initialValue,
    required this.value,
    this.duration,
    this.durationBuilder,
    required AnimatedChildBuilder<T> this.builder,
    this.onEnd,
    this.curve = Curves.linear,
    this.lerp,
    this.child,
  })  : animationBuilder = null,
        assert(duration != null || durationBuilder != null,
            'You must provide a duration or a durationBuilder.'),
        super(key: key);

  const AnimatedValueBuilder.animation({
    Key? key,
    this.initialValue,
    required this.value,
    this.duration,
    this.durationBuilder,
    required AnimationBuilder<T> builder,
    this.onEnd,
    this.curve = Curves.linear,
    this.lerp,
  })  : builder = null,
        animationBuilder = builder,
        child = null,
        assert(duration != null || durationBuilder != null,
            'You must provide a duration or a durationBuilder.'),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return AnimatedValueBuilderState<T>();
  }
}

class AnimatedValueBuilderState<T> extends State<AnimatedValueBuilder<T>>
    with SingleTickerProviderStateMixin
    implements Animation<T> {
  late AnimationController _controller;
  late T _value;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: widget.duration ??
            widget.durationBuilder!(
                widget.initialValue ?? widget.value, widget.value));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onEnd();
      }
    });
    if (widget.animationBuilder == null) {
      // animationBuilder does not need the widget to be rebuilt
      _controller.addListener(() {
        setState(() {});
      });
    }
    _value = widget.initialValue ?? widget.value;
    if (widget.initialValue != null) {
      _controller.forward();
    }
  }

  T lerpedValue(T a, T b, double t) {
    if (widget.lerp != null) {
      return widget.lerp!(a, b, t);
    }
    try {
      return (a as dynamic) + ((b as dynamic) - (a as dynamic)) * t;
    } catch (e) {
      throw Exception(
        'Could not lerp $a and $b. You must provide a custom lerp function.',
      );
    }
  }

  @override
  void didUpdateWidget(AnimatedValueBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.duration != widget.duration ||
        oldWidget.curve != widget.curve ||
        oldWidget.durationBuilder != widget.durationBuilder) {
      T currentValue = _controller.value == 1
          ? oldWidget.value
          : lerpedValue(
              _value,
              oldWidget.value,
              oldWidget.curve.transform(_controller.value),
            );
      _controller.duration = widget.duration ??
          widget.durationBuilder!(currentValue, widget.value);
      _value = currentValue;
      _controller.forward(
        from: 0,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnd() {
    if (widget.onEnd != null) {
      widget.onEnd!(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animationBuilder != null) {
      return widget.animationBuilder!(context, this);
    }
    double progress = _controller.value;
    double curveProgress = widget.curve.transform(progress);
    if (progress == 1) {
      return widget.builder!(context, widget.value, widget.child);
    }
    T newValue = lerpedValue(_value, widget.value, curveProgress);
    return widget.builder!(context, newValue, widget.child);
  }

  @override
  void addListener(VoidCallback listener) {
    _controller.addListener(listener);
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    _controller.addStatusListener(listener);
  }

  @override
  Animation<U> drive<U>(Animatable<U> child) {
    return _controller.drive(child);
  }

  @override
  bool get isCompleted => _controller.isCompleted;

  @override
  bool get isDismissed => _controller.isDismissed;

  @override
  void removeListener(VoidCallback listener) {
    _controller.removeListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    _controller.removeStatusListener(listener);
  }

  @override
  AnimationStatus get status => _controller.status;

  @override
  String toStringDetails() {
    return 'value: $_value, controller: $_controller';
  }

  @override
  T get value {
    double progress = _controller.value;
    double curveProgress = widget.curve.transform(progress);
    if (progress == 0) {
      return _value;
    }
    if (progress == 1) {
      return widget.value;
    }
    T newValue = lerpedValue(_value, widget.value, curveProgress);
    return newValue;
  }
}

enum RepeatMode {
  repeat,
  reverse,
  pingPong,
}

class RepeatedAnimationBuilder<T> extends StatefulWidget {
  final T start;
  final T end;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve curve;
  final Curve? reverseCurve;
  final RepeatMode mode;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;
  final T Function(T a, T b, double t)? lerp;
  final bool play;

  const RepeatedAnimationBuilder({
    Key? key,
    required this.start,
    required this.end,
    required this.duration,
    this.curve = Curves.linear,
    this.reverseCurve,
    this.mode = RepeatMode.repeat,
    required this.builder,
    this.child,
    this.lerp,
    this.play = true,
    this.reverseDuration,
  }) : super(key: key);

  @override
  State<RepeatedAnimationBuilder<T>> createState() =>
      _RepeatedAnimationBuilderState<T>();
}

class _RepeatedAnimationBuilderState<T>
    extends State<RepeatedAnimationBuilder<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
    );
    if (widget.play) {
      switch (widget.mode) {
        case RepeatMode.repeat:
          _controller.repeat(reverse: false);
          break;
        case RepeatMode.reverse:
          _controller.repeat(reverse: false);
          break;
        case RepeatMode.pingPong:
          _controller.repeat(reverse: true);
          break;
      }
    }
  }

  @override
  void didUpdateWidget(covariant RepeatedAnimationBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start ||
        oldWidget.end != widget.end ||
        oldWidget.duration != widget.duration ||
        oldWidget.reverseDuration != widget.reverseDuration) {
      _controller.duration = widget.duration;
      _controller.reverseDuration = widget.reverseDuration;
      _controller.stop();
      if (widget.play) {
        switch (widget.mode) {
          case RepeatMode.repeat:
            _controller.repeat(reverse: false);
            break;
          case RepeatMode.reverse:
            _controller.repeat(reverse: false);
            break;
          case RepeatMode.pingPong:
            _controller.repeat(reverse: true);
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  T lerpedValue(T a, T b, double t) {
    if (widget.lerp != null) {
      return widget.lerp!(a, b, t);
    }
    try {
      return (a as dynamic) + ((b as dynamic) - (a as dynamic)) * t;
    } catch (e) {
      throw Exception(
        'Could not lerp $a and $b. You must provide a custom lerp function.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double progress = _controller.value;
        AnimationStatus status = _controller.status;
        if (widget.mode == RepeatMode.reverse) {
          progress = 1 - progress;
        }
        double curveProgress = status == AnimationStatus.reverse ||
                widget.mode == RepeatMode.reverse
            ? (widget.reverseCurve ?? widget.curve).transform(progress)
            : widget.curve.transform(progress);
        T value = lerpedValue(widget.start, widget.end, curveProgress);
        return widget.builder(context, value, widget.child);
      },
    );
  }
}
