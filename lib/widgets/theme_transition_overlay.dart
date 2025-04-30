import 'dart:math';

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

class _ThemeTransitionOverlayState extends State<ThemeTransitionOverlay>
    with SingleTickerProviderStateMixin {
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

        // Overlay con fondo animado y animación
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _calculateOpacity(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _buildGradient(themeProvider),
                  ),
                  child: child,
                ),
              );
            },
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

  // Calcula la opacidad basada en el progreso de la animación
  double _calculateOpacity() {
    if (_controller.value < 0.15) {
      // Primeros fotogramas: rápidamente de 0 a 1
      return _controller.value / 0.15; // 0->0, 0.075->0.5, 0.15->1.0
    } else if (_controller.value > 0.85) {
      // Últimos fotogramas: rápidamente de 1 a 0
      return (1.0 - _controller.value) / 0.15; // 0.85->1.0, 0.925->0.5, 1.0->0
    } else {
      // En el medio: completamente opaco
      return 1.0;
    }
  }

  // Construye el degradado según el valor de la animación y el tema objetivo
  Gradient? _buildGradient(ThemeProvider themeProvider) {
    // Degradado personalizado (puedes ajustar estos colores)
    final colorGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.purple.shade600, Colors.blue.shade900],
    );

    // Color sólido negro para el estado oscuro
    final blackColor = LinearGradient(colors: [Colors.black, Colors.black]);

    // Si vamos a modo oscuro: degradado -> negro
    if (themeProvider.targetThemeMode == ThemeMode.dark) {
      if (_controller.value < 0.5) {
        // Primera mitad: mostrar degradado
        return colorGradient;
      } else {
        // Segunda mitad: transición suave de degradado a negro
        // Calcular un factor de transición suave entre 0 y 1
        final t = (_controller.value - 0.5) * 2;
        final factor = t * t * (3 - 2 * t);
        
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.purple.shade600, Colors.black, factor)!,
            Color.lerp(Colors.blue.shade900, Colors.black, factor)!,
          ],
        );
      }
    }
    // Si vamos a modo claro: negro -> degradado
    else {
      if (_controller.value < 0.5) {
        // Primera mitad: mostrar negro
        return blackColor;
      } else {
        // Segunda mitad: transición suave de negro a degradado
        // Calcular un factor de transición suave entre 0 y 1
        final t = (_controller.value - 0.5) * 2;
        final factor = t * t * (3 - 2 * t);
        
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.black, Colors.purple.shade600, factor)!,
            Color.lerp(Colors.black, Colors.blue.shade900, factor)!,
          ],
        );
      }
    }
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
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).completeThemeChange();
      }
    }

    // Agregar listeners
    _controller.addListener(onHalfway);
    _controller.addStatusListener(onComplete);

    // Iniciar animación
    _controller.forward();
  }
}
