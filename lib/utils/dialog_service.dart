import 'package:flutter/material.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class DialogService {
  // Simple confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = 'Cancelar',
    String confirmText = 'Confirmar',
    Color? confirmColor,
    Color? cancelColor,
    bool barrierDismissible = true,
    ShapeBorder? shape,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(
          title, 
          style: chatTheme?.dialogTitleStyle,
        ),
        content: Text(
          content,
          style: chatTheme?.dialogContentStyle,
        ),
        backgroundColor: backgroundColor ?? 
            chatTheme?.dialogBackgroundColor ?? 
            theme.dialogBackgroundColor,
        shape: shape ?? RoundedRectangleBorder(
          borderRadius: chatTheme?.dialogBorderRadius ?? BorderRadius.circular(16.0),
        ),
        // Center the actions using a Column instead of default ButtonBar
        actionsAlignment: MainAxisAlignment.center, // Center the buttons horizontally
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: cancelColor ?? 
                  chatTheme?.dialogSecondaryButtonColor ?? 
                  theme.colorScheme.secondary,
            ),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: confirmColor ?? 
                  chatTheme?.dialogPrimaryButtonColor ?? 
                  theme.colorScheme.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // Form dialog with custom content and consistent theming
  static Future<T?> showFormDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    ShapeBorder? shape,
    Color? backgroundColor,
    Color? actionColor,
    Color? secondaryActionColor,
    // Form theming options
    InputDecorationTheme? inputDecorationTheme,
    Color? fieldBackgroundColor,
    Color? radioActiveColor,
    Color? checkboxActiveColor,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    BorderRadius? fieldBorderRadius,
  }) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    
    // Create custom input decoration theme for form fields
    final effectiveInputDecorationTheme = inputDecorationTheme ?? 
        chatTheme?.dialogInputDecorationTheme ??
        theme.inputDecorationTheme.copyWith(
          filled: fieldBackgroundColor != null || chatTheme?.dialogFieldBackgroundColor != null,
          fillColor: fieldBackgroundColor ?? chatTheme?.dialogFieldBackgroundColor,
          labelStyle: labelStyle ?? theme.inputDecorationTheme.labelStyle,
          hintStyle: hintStyle ?? theme.inputDecorationTheme.hintStyle,
          border: OutlineInputBorder(
            borderRadius: fieldBorderRadius ?? 
                (chatTheme?.dialogBorderRadius != null 
                  ? BorderRadius.all(chatTheme!.dialogBorderRadius!.topLeft)
                  : BorderRadius.circular(8.0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: fieldBorderRadius ?? 
                (chatTheme?.dialogBorderRadius != null 
                  ? BorderRadius.all(chatTheme!.dialogBorderRadius!.topLeft)
                  : BorderRadius.circular(8.0)),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: fieldBorderRadius ?? 
                (chatTheme?.dialogBorderRadius != null 
                  ? BorderRadius.all(chatTheme!.dialogBorderRadius!.topLeft)
                  : BorderRadius.circular(8.0)),
            borderSide: BorderSide(
              color: theme.colorScheme.primary, 
              width: 2.0
            ),
          ),
        );
    
    // Create a theme override specifically for the form content
    final formTheme = theme.copyWith(
      inputDecorationTheme: effectiveInputDecorationTheme,
      checkboxTheme: theme.checkboxTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return checkboxActiveColor ?? 
                chatTheme?.dialogCheckboxActiveColor ?? 
                theme.colorScheme.primary;
          }
          return null;
        }),
      ),
      radioTheme: theme.radioTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return radioActiveColor ?? 
                chatTheme?.dialogRadioActiveColor ?? 
                theme.colorScheme.primary;
          }
          return null;
        }),
      ),
    );

    // Determine the action colors based on theme
    final effectivePrimaryActionColor = actionColor ?? 
        chatTheme?.dialogPrimaryButtonColor ?? 
        theme.colorScheme.primary;
        
    final effectiveSecondaryActionColor = secondaryActionColor ?? 
        chatTheme?.dialogSecondaryButtonColor ?? 
        theme.colorScheme.secondary;

    // Wrap custom actions with themed buttons if provided
    List<Widget> themedActions = [];
    if (actions != null && actions.isNotEmpty) {
      for (int i = 0; i < actions.length; i++) {
        final action = actions[i];
        // Apply theming to TextButtons specifically
        if (action is TextButton) {
          themedActions.add(TextButton(
            onPressed: action.onPressed,
            style: TextButton.styleFrom(
              foregroundColor: i == actions.length-1 
                  ? effectivePrimaryActionColor 
                  : effectiveSecondaryActionColor,
            ),
            child: action.child ?? const Text(''),
          ));
        } else {
          themedActions.add(action);
        }
      }
    } else {
      // Default close button
      themedActions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: effectivePrimaryActionColor,
          ),
          child: const Text('Cerrar'),
        ),
      ];
    }

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(
          title, 
          style: chatTheme?.dialogTitleStyle,
        ),
        content: Theme(
          data: formTheme,
          child: SingleChildScrollView(
            child: content,
          ),
        ),
        backgroundColor: backgroundColor ?? 
            chatTheme?.dialogBackgroundColor ?? 
            theme.dialogBackgroundColor,
        shape: shape ?? RoundedRectangleBorder(
          borderRadius: chatTheme?.dialogBorderRadius ?? BorderRadius.circular(16.0),
        ),
        // Center the buttons horizontally
        actionsAlignment: MainAxisAlignment.center,
        // Use the themed actions
        actions: themedActions,
      ),
    );
  }

  // Custom dialog with flexible structure
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      builder: builder,
    );
  }
}