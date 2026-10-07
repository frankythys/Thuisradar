import 'package:flutter/material.dart';

/// Inhoud van de aparte plaatsenkaart onder de gezinsleden.
class MemberPlacesPrompt extends StatelessWidget {
  const MemberPlacesPrompt({super.key, required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: ExcludeSemantics(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFF1EBFC),
                child: Icon(Icons.home_rounded, size: 54, color: Color(0xFF7952AC)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sla de plaatsen op die het belangrijkst zijn',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontSize: 20, height: 1.3, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Weet wanneer ze aankomen',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(fontSize: 17, color: const Color(0xFF787083)),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEDEBEF),
              foregroundColor: const Color(0xFF393342),
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: text.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            child: const Text('Beheer plaatsen', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
