import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// One accessible input, eight visual cells; supports paste and autofill.
class InviteCodeInput extends StatelessWidget {
  const InviteCodeInput({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => SizedBox(
      height: 54,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Row(
                children: [
                  for (var i = 0; i < 8; i++)
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          i < value.text.length ? value.text[i].toUpperCase() : '•',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: i < value.text.length ? AppColors.primary : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextField(
            controller: controller,
            maxLength: 8,
            showCursor: false,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.transparent),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Toegangscode',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: TextStyle(color: Colors.transparent),
              filled: false,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    ),
  );
}
