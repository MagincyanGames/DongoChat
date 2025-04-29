import 'package:flutter/material.dart';

class ChatTheme extends ThemeExtension<ChatTheme> {
  final List<Color> myMessageGradient;
  final List<Color> otherMessageGradient;
  
  // Para citas de mis mensajes
  final Color myQuotedMessageBorderColor;
  final Color myQuotedMessageBackgroundColor;
  
  // Para citas de mensajes de otros
  final Color otherQuotedMessageBorderColor;
  final Color otherQuotedMessageBackgroundColor;
  
  // Comunes para ambos tipos de citas
  final Color quotedMessageTextColor;
  final Color quotedMessageNameColor;
  
  ChatTheme({
    required this.myMessageGradient,
    required this.otherMessageGradient,
    required this.myQuotedMessageBorderColor,
    required this.myQuotedMessageBackgroundColor,
    required this.otherQuotedMessageBorderColor,
    required this.otherQuotedMessageBackgroundColor,
    required this.quotedMessageTextColor,
    required this.quotedMessageNameColor,
  });
  
  // Propiedades de conveniencia para compatibilidad con el código existente
  Color get quotedMessageBorderColor => myQuotedMessageBorderColor;
  Color get quotedMessageBackgroundColor => myQuotedMessageBackgroundColor;
  
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
    );
  }
}