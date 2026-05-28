import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard back button for full-screen routes outside the bottom-nav shell.
///
/// Pops the current route when something is on the stack; otherwise falls
/// back to `/home`. This matters because drawer navigation uses
/// `context.go(...)` which often replaces rather than pushes, so the
/// platform's auto-back arrow may not appear. Using this widget gives
/// every page a guaranteed, visible "back" affordance.
class AppBackButton extends StatelessWidget {
  /// Optional override — when set, tapping the button navigates to this
  /// route instead of the default pop/home behaviour. Useful for forms
  /// that should always return to a specific parent.
  final String? fallbackRoute;

  const AppBackButton({super.key, this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackRoute ?? '/home');
        }
      },
    );
  }
}
