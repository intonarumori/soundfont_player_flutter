import 'package:flutter/material.dart';

class TapButton extends StatelessWidget {
  const TapButton({
    super.key,
    required this.onTapDown,
    required this.onTapUp,
  });

  final void Function() onTapDown;
  final void Function() onTapUp;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onTapDown.call(),
      onPointerUp: (_) => onTapUp.call(),
      child: Container(
        color: Colors.blue,
      ),
    );
  }
}
