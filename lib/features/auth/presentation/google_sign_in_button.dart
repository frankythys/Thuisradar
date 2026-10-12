import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Light Google button: https://developers.google.com/identity/branding-guidelines
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        disabledForegroundColor: const Color(0xFF747775),
        side: const BorderSide(color: Color(0xFF747775)),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(48),
        padding: EdgeInsets.symmetric(horizontal: isIos ? 16 : 12, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Google Sans',
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/illustrations/google_g.svg', width: 20, height: 20, excludeFromSemantics: true),
          SizedBox(width: isIos ? 12 : 10),
          const Flexible(child: Text('Doorgaan met Google')),
        ],
      ),
    );
  }
}
