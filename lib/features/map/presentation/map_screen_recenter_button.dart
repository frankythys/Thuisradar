part of 'map_screen.dart';

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x33121C1C),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Tooltip(
          message: 'Toon iedereen',
          child: SizedBox(width: 48, height: 48, child: Icon(Icons.my_location, color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// Banner voor de verzender zelf: zijn SOS is actief, met een knop om op te lossen.
