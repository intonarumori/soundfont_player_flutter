import 'package:flutter/widgets.dart';
import 'package:soundfont_player_example/tap_button.dart';

class GridButtons extends StatelessWidget {
  const GridButtons({
    super.key,
    required this.onTapDown,
    required this.onTapUp,
  });

  final void Function(int index) onTapDown;
  final void Function(int index) onTapUp;

  @override
  Widget build(BuildContext context) {
    return GridView.custom(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        mainAxisExtent: 50,
      ),
      childrenDelegate: SliverChildListDelegate(
        List.generate(
          16,
          (index) => TapButton(
            onTapDown: () => onTapDown.call(index),
            onTapUp: () => onTapUp.call(index),
          ),
        ),
      ),
    );
  }
}
