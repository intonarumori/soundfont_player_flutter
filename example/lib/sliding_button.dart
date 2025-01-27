import 'package:flutter/material.dart';

class SlidingButton extends StatefulWidget {
  const SlidingButton({
    super.key,
    required this.tapStarted,
    required this.tapUpdated,
    required this.tapEnded,
  });

  final void Function(double value) tapStarted;
  final void Function(double value) tapUpdated;
  final void Function(double value) tapEnded;

  @override
  State<SlidingButton> createState() => _SlidingButtonState();
}

class _SlidingButtonState extends State<SlidingButton> {
  void _tapStarted(PointerDownEvent details) {
    final value = (details.localPosition.dx / size.width).clamp(0, 1);
    widget.tapStarted(value.toDouble());
  }

  void _tapUpdated(PointerMoveEvent details) {
    final value = (details.localPosition.dx / size.width).clamp(0, 1);
    widget.tapUpdated(value.toDouble());
  }

  void _tapEnded(PointerUpEvent details) {
    final value = (details.localPosition.dx / size.width).clamp(0, 1);
    widget.tapEnded(value.toDouble());
  }

  get size => context.size ?? Size(100, 100);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _tapStarted,
      onPointerMove: _tapUpdated,
      onPointerUp: _tapEnded,
      child: Container(
        color: Colors.blue,
        width: 200,
        height: 50,
      ),
    );
  }
}
