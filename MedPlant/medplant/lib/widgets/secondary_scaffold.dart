// lib/widgets/secondary_scaffold.dart
//
// One shared layout for every secondary (non-tab) page: Add Report,
// Plant Detail, Report Review, About, Contact, Contact Messages, etc.
//
//  • Consistent green AppBar with a back arrow on the left.
//  • The back arrow AND the phone's system back button both go to the
//    previous screen. If there is nothing to go back to (e.g. the page
//    was opened directly), they fall back to Home instead of closing
//    the app.
//  • Body is kept clear of the phone's bottom navigation / gesture bar.
//  • Content is centred and capped to [maxWidth] so it scales well on
//    tablets, desktops and the web.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

/// Pops the current page if possible, otherwise returns to Home.
void goBackOrHome(BuildContext context, {String fallback = '/home'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

class SecondaryScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final double maxWidth;
  final Color backgroundColor;

  /// Where to go if there is no previous page to pop back to.
  final String fallbackRoute;

  const SecondaryScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.maxWidth = 900,
    this.backgroundColor = AppColors.pageBg,
    this.fallbackRoute = '/home',
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // If there is a previous page, let the system pop normally (keeps
      // the iOS swipe-back gesture). If not (deep link, web refresh),
      // intercept and return to Home rather than exiting the app.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goBackOrHome(context, fallback: fallbackRoute);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => goBackOrHome(context, fallback: fallbackRoute),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          actions: actions,
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar == null
            ? null
            : SafeArea(top: false, child: bottomBar!),
        body: SafeArea(
          top: false,
          bottom: bottomBar == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
