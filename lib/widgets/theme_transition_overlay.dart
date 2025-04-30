import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';

/// Overlay simple que muestra una animación durante el cambio de tema
class ThemeTransitionOverlay extends StatefulWidget {
  final Widget child;
  final bool testMode;

  const ThemeTransitionOverlay({
    Key? key, 
    required this.child,
    this.testMode = false,
  }) : super(key: key);

  @override
  State<ThemeTransitionOverlay> createState() => _ThemeTransitionOverlayState();
}

class _ThemeTransitionOverlayState extends State<ThemeTransitionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Iniciar animación si es necesario
    if (themeProvider.isChangingTheme && !_controller.isAnimating) {
      _startAnimation(themeProvider);
    }
    
    // Si no hay transición, mostrar contenido normal
    if (!themeProvider.isChangingTheme && !_controller.isAnimating) {
      return widget.child;
    }
    
    // Durante la transición, mostrar animación sobre fondo negro
    return Stack(
      children: [
        // Contenido de la app
        widget.child,
        
        // Overlay con fondo negro y animación
        Positioned.fill(
          child: Container(
            child: Center(
              child: Lottie.asset(
                themeProvider.targetThemeMode == ThemeMode.dark
                  ? 'assets/animations/dark_theme_loading.json'
                  : 'assets/animations/light_theme_loading.json',
                width: 300,
                height: 300,
                controller: _controller,
                fit: BoxFit.contain,
                repeat: false,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _startAnimation(ThemeProvider themeProvider) {
    _controller.reset();
    
    // Aplicar el tema cuando la animación llegue a la mitad
    void onHalfway() {
      if (_controller.value > 0.5 && mounted && !widget.testMode) {
        Provider.of<ThemeProvider>(context, listen: false).applyThemeChange();
        _controller.removeListener(onHalfway);
      }
    }
    
    // Completar la transición cuando termine la animación
    void onComplete(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted && !widget.testMode) {
        Provider.of<ThemeProvider>(context, listen: false).completeThemeChange();
      }
    }
    
    // Agregar listeners
    _controller.addListener(onHalfway);
    _controller.addStatusListener(onComplete);
    
    // Iniciar animación
    _controller.forward();
  }
}