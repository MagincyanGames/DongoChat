import 'package:flutter/material.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget child;
  final bool avoidBottomNavBar;
  final Color? backgroundColor;

  const ScreenWrapper({
    Key? key,
    required this.child,
    this.avoidBottomNavBar = true,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
                         MediaQuery.of(context).viewPadding.bottom;

    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: avoidBottomNavBar,
        child: child,
      ),
    );
  }
}