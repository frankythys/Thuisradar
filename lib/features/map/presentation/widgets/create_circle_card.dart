import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Kaart onder de personenlijst om een aparte groep te starten.
class CreateCircleCard extends StatelessWidget {
  const CreateCircleCard({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.ink;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.family_restroom_rounded, size: 54, color: Color(0xFF796294)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start een Circle voor je familie of vrienden',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17151C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Houd elke groep beschermd, zonder dingen door elkaar te halen.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontSize: 17, height: 1.4, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              elevation: 3,
              shadowColor: const Color(0x660F1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            child: const Text('Nieuwe Circle aanmaken', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
