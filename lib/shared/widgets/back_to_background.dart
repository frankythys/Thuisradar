import 'package:flutter/widgets.dart';

/// Op het hoofdscherm sluit "terug" de app niet, maar roept [onBackground]
/// (de app naar de achtergrond), zodat het delen van de locatie doorloopt.
/// Schermen die erbovenop geopend zijn, gaan gewoon terug.
class BackToBackground extends StatelessWidget {
  const BackToBackground({super.key, required this.onBackground, required this.child});

  final VoidCallback onBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackground();
      },
      child: child,
    );
  }
}
