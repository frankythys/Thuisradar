part of 'map_screen.dart';

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      // Blauwe rand in de kleur van de app (zelfde als de auto- en kaartknop).
      shape: CircleBorder(
        side: BorderSide(color: AppColors.primary, width: context.tokens.spaceXs / 2),
      ),
      elevation: 3,
      shadowColor: const Color(0x33121C1C),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: context.l10n.mapShowEveryone,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.my_location, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Banner voor de verzender zelf: zijn SOS is actief, met een knop om op te lossen.
