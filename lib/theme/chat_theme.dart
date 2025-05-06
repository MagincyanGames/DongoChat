import 'package:flutter/material.dart';

// Add this extension at the top of your file, outside any class
extension GradientScaleOpacity on Gradient {
  Gradient scale(double opacity) {
    if (this is LinearGradient) {
      final LinearGradient linearGradient = this as LinearGradient;
      return LinearGradient(
        begin: linearGradient.begin,
        end: linearGradient.end,
        colors: linearGradient.colors.map((color) => color.withOpacity(color.opacity * opacity)).toList(),
        stops: linearGradient.stops,
        tileMode: linearGradient.tileMode,
      );
    }
    return this;
  }
}

class ChatTheme extends ThemeExtension<ChatTheme> {
  final List<Color> myMessageGradient;
  final List<Color> otherMessageGradient;
  
  final Color myQuotedMessageBorderColor;
  final Color myQuotedMessageBackgroundColor;
  
  final Color otherQuotedMessageBorderColor;
  final Color otherQuotedMessageBackgroundColor;
  
  final Color quotedMessageTextColor;
  final Color quotedMessageNameColor;
  
  // Action icon color
  final Color actionIconColor;
  
  // Dialog theme properties
  final Color? dialogBackgroundColor;
  final BorderRadius? dialogBorderRadius;
  final Color? dialogPrimaryButtonColor;
  final Color? dialogSecondaryButtonColor;
  final TextStyle? dialogTitleStyle;
  final TextStyle? dialogContentStyle;
  final Color? dialogFieldBackgroundColor;
  final InputDecorationTheme? dialogInputDecorationTheme;
  final Color? dialogRadioActiveColor;
  final Color? dialogCheckboxActiveColor;

  ChatTheme({
    required this.myMessageGradient,
    required this.otherMessageGradient,
    required this.myQuotedMessageBorderColor,
    required this.myQuotedMessageBackgroundColor,
    required this.otherQuotedMessageBorderColor,
    required this.otherQuotedMessageBackgroundColor,
    required this.quotedMessageTextColor,
    required this.quotedMessageNameColor,
    this.actionIconColor = Colors.white,
    // Dialog theme properties with default values of null
    this.dialogBackgroundColor,
    this.dialogBorderRadius,
    this.dialogPrimaryButtonColor,
    this.dialogSecondaryButtonColor,
    this.dialogTitleStyle,
    this.dialogContentStyle,
    this.dialogFieldBackgroundColor,
    this.dialogInputDecorationTheme,
    this.dialogRadioActiveColor,
    this.dialogCheckboxActiveColor,
  });
  
  // Convenience properties for backward compatibility
  Color get quotedMessageBorderColor => myQuotedMessageBorderColor;
  Color get quotedMessageBackgroundColor => myQuotedMessageBackgroundColor;

  get unreadChatGradientStart => null;
  
  @override
  ThemeExtension<ChatTheme> copyWith({
    List<Color>? myMessageGradient,
    List<Color>? otherMessageGradient,
    Color? myQuotedMessageBorderColor,
    Color? myQuotedMessageBackgroundColor,
    Color? otherQuotedMessageBorderColor,
    Color? otherQuotedMessageBackgroundColor,
    Color? quotedMessageTextColor,
    Color? quotedMessageNameColor,
    Color? actionIconColor,
    // Dialog theme properties
    Color? dialogBackgroundColor,
    BorderRadius? dialogBorderRadius,
    Color? dialogPrimaryButtonColor,
    Color? dialogSecondaryButtonColor,
    TextStyle? dialogTitleStyle,
    TextStyle? dialogContentStyle,
    Color? dialogFieldBackgroundColor,
    InputDecorationTheme? dialogInputDecorationTheme,
    Color? dialogRadioActiveColor,
    Color? dialogCheckboxActiveColor,
  }) {
    return ChatTheme(
      myMessageGradient: myMessageGradient ?? this.myMessageGradient,
      otherMessageGradient: otherMessageGradient ?? this.otherMessageGradient,
      myQuotedMessageBorderColor: myQuotedMessageBorderColor ?? this.myQuotedMessageBorderColor,
      myQuotedMessageBackgroundColor: myQuotedMessageBackgroundColor ?? this.myQuotedMessageBackgroundColor,
      otherQuotedMessageBorderColor: otherQuotedMessageBorderColor ?? this.otherQuotedMessageBorderColor,
      otherQuotedMessageBackgroundColor: otherQuotedMessageBackgroundColor ?? this.otherQuotedMessageBackgroundColor,
      quotedMessageTextColor: quotedMessageTextColor ?? this.quotedMessageTextColor,
      quotedMessageNameColor: quotedMessageNameColor ?? this.quotedMessageNameColor,
      actionIconColor: actionIconColor ?? this.actionIconColor,
      // Dialog theme properties
      dialogBackgroundColor: dialogBackgroundColor ?? this.dialogBackgroundColor,
      dialogBorderRadius: dialogBorderRadius ?? this.dialogBorderRadius,
      dialogPrimaryButtonColor: dialogPrimaryButtonColor ?? this.dialogPrimaryButtonColor,
      dialogSecondaryButtonColor: dialogSecondaryButtonColor ?? this.dialogSecondaryButtonColor,
      dialogTitleStyle: dialogTitleStyle ?? this.dialogTitleStyle,
      dialogContentStyle: dialogContentStyle ?? this.dialogContentStyle,
      dialogFieldBackgroundColor: dialogFieldBackgroundColor ?? this.dialogFieldBackgroundColor,
      dialogInputDecorationTheme: dialogInputDecorationTheme ?? this.dialogInputDecorationTheme,
      dialogRadioActiveColor: dialogRadioActiveColor ?? this.dialogRadioActiveColor,
      dialogCheckboxActiveColor: dialogCheckboxActiveColor ?? this.dialogCheckboxActiveColor,
    );
  }
  
  @override
  ThemeExtension<ChatTheme> lerp(ThemeExtension<ChatTheme>? other, double t) {
    if (other is! ChatTheme) {
      return this;
    }
    return ChatTheme(
      myMessageGradient: [
        Color.lerp(myMessageGradient[0], other.myMessageGradient[0], t)!,
        Color.lerp(myMessageGradient[1], other.myMessageGradient[1], t)!,
      ],
      otherMessageGradient: [
        Color.lerp(otherMessageGradient[0], other.otherMessageGradient[0], t)!,
        Color.lerp(otherMessageGradient[1], other.otherMessageGradient[1], t)!,
      ],
      myQuotedMessageBorderColor: Color.lerp(myQuotedMessageBorderColor, other.myQuotedMessageBorderColor, t)!,
      myQuotedMessageBackgroundColor: Color.lerp(myQuotedMessageBackgroundColor, other.myQuotedMessageBackgroundColor, t)!,
      otherQuotedMessageBorderColor: Color.lerp(otherQuotedMessageBorderColor, other.otherQuotedMessageBorderColor, t)!,
      otherQuotedMessageBackgroundColor: Color.lerp(otherQuotedMessageBackgroundColor, other.otherQuotedMessageBackgroundColor, t)!,
      quotedMessageTextColor: Color.lerp(quotedMessageTextColor, other.quotedMessageTextColor, t)!,
      quotedMessageNameColor: Color.lerp(quotedMessageNameColor, other.quotedMessageNameColor, t)!,
      actionIconColor: Color.lerp(actionIconColor, other.actionIconColor, t)!,
      // Dialog theme properties lerp
      dialogBackgroundColor: Color.lerp(dialogBackgroundColor, other.dialogBackgroundColor, t),
      dialogBorderRadius: BorderRadius.lerp(dialogBorderRadius, other.dialogBorderRadius, t),
      dialogPrimaryButtonColor: Color.lerp(dialogPrimaryButtonColor, other.dialogPrimaryButtonColor, t),
      dialogSecondaryButtonColor: Color.lerp(dialogSecondaryButtonColor, other.dialogSecondaryButtonColor, t),
      dialogTitleStyle: TextStyle.lerp(dialogTitleStyle, other.dialogTitleStyle, t),
      dialogContentStyle: TextStyle.lerp(dialogContentStyle, other.dialogContentStyle, t),
      dialogFieldBackgroundColor: Color.lerp(dialogFieldBackgroundColor, other.dialogFieldBackgroundColor, t),
      dialogInputDecorationTheme: other.dialogInputDecorationTheme,  // Can't lerp InputDecorationTheme easily
      dialogRadioActiveColor: Color.lerp(dialogRadioActiveColor, other.dialogRadioActiveColor, t),
      dialogCheckboxActiveColor: Color.lerp(dialogCheckboxActiveColor, other.dialogCheckboxActiveColor, t),
    );
  }
}