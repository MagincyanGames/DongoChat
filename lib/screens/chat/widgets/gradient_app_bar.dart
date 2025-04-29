import 'package:flutter/material.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class GradientChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  
  const GradientChatAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    
    // Get gradient colors from theme
    final otherMessageColors = chatTheme?.otherMessageGradient ?? 
        [Colors.blue.shade900, Colors.blue.shade700];
    final myMessageColors = chatTheme?.myMessageGradient ?? 
        [Colors.deepPurple, Colors.deepPurple.shade900];
    
    // Use the first color from each gradient for the app bar gradient
    final gradientColors = [
      otherMessageColors.first,
      myMessageColors.last,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: centerTitle,
        leading: leading,
        actions: actions,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
    );
  }
}