import 'package:flutter/material.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class GradientSlideUpPageRoute extends PageRouteBuilder {
  final Widget page;
  final BuildContext context;
  final Map<String, dynamic>? arguments;

  GradientSlideUpPageRoute({
    required this.page,
    required this.context,
    this.arguments,
  }) : super(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Create curved animation
            var curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
            );

            // Get theme for gradient colors
            final theme = Theme.of(context);
            final chatTheme = theme.extension<ChatTheme>();
            
            return Stack(
              children: [
                // Background image (stays static)
                Positioned.fill(
                  child: SizedBox.expand(
                    child: Image.asset(
                      'assets/ajolote contrast.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      opacity: const AlwaysStoppedAnimation(0.1),
                      colorBlendMode: BlendMode.multiply,
                    ),
                  ),
                ),
                
                // Animated gradient that slides up
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1), // Start from bottom
                    end: const Offset(0, 0),   // End at top
                  ).animate(curvedAnimation),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          chatTheme?.otherMessageGradient.last ?? Colors.blue.shade900,
                          chatTheme?.myMessageGradient.first ?? Colors.deepPurple.shade900,
                        ],
                      ).withOpacity(0.1),
                    ),
                  ),
                ),
                
                // Content with fade and slight slide transition
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(curvedAnimation),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
}