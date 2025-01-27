import 'dart:math';

import 'package:flutter/material.dart';

class VerticalSlider extends StatefulWidget {
  const VerticalSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.division = 1,
  });

  final int value;
  final int min;
  final int max;
  final double division;
  final ValueChanged<int> onChanged;

  @override
  State<VerticalSlider> createState() => _VerticalSliderState();
}

class _VerticalSliderState extends State<VerticalSlider> {
  int _value = 0;
  Offset _panDragStart = Offset.zero;
  int _panValueStart = 0;

  Offset _tooltipPosition = Offset.zero;
  final OverlayPortalController _tooltipController = OverlayPortalController();

  @override
  void initState() {
    _value = widget.value;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant VerticalSlider oldWidget) {
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          onPanStart: (details) {
            _panValueStart = _value;
            _panDragStart = details.localPosition;
            _tooltipPosition = details.globalPosition;
            _tooltipController.show();
          },
          onPanUpdate: (details) {
            final size = context.size ?? const Size(30, 100);
            final normalizationCoeff = size.height / (widget.max - widget.min);
            final translation = details.localPosition - _panDragStart;
            final newValue = (_panValueStart - translation.dy / normalizationCoeff)
                .toInt()
                .clamp(widget.min, widget.max);
            setState(() {
              _tooltipPosition = details.globalPosition;
              _value = newValue;
              widget.onChanged(newValue);
            });
          },
          onPanEnd: (details) {
            _tooltipController.hide();
          },
          onPanCancel: () {
            _tooltipController.hide();
          },
          onDoubleTap: () {
            _value = (widget.max + widget.min) ~/ 2;
            widget.onChanged(_value);
            setState(() {});
          },
          child: OverlayPortal(
            controller: _tooltipController,
            overlayChildBuilder: (BuildContext context) => Positioned(
              left: _tooltipPosition.dx - 25,
              top: _tooltipPosition.dy - 25,
              width: 50,
              height: 50,
              child: const MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final normalized =
                  (_value - widget.min) / (widget.max - widget.min) - 0.5; // [-0.5, 0.5]

              final height = normalized * constraints.maxHeight;

              final bar = Container(
                decoration: BoxDecoration(
                  color: normalized > 0
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.tertiaryContainer,
                ),
              );

              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: constraints.maxHeight / 2 - max(height, 0),
                    left: 0,
                    width: constraints.maxWidth,
                    height: height.abs(),
                    child: bar,
                  ),
                  Container(
                    height: 1,
                    width: constraints.maxWidth,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Column(
                    children: [
                      const Spacer(),
                      Text(_value.toString()),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
