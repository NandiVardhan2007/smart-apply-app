import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  // Optimize scrollbars for a cleaner UI
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return RawScrollbar(
      controller: details.controller,
      shape: const StadiumBorder(),
      thickness: 3,
      padding: const EdgeInsets.only(right: 2),
      thumbColor: Colors.white.withValues(alpha: 0.1),
      child: child,
    );
  }
}
