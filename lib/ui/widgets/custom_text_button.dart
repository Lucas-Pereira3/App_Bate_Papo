import 'package:flutter/material.dart';

class CustomTextButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback buttonAction;
  final Color? textColor;
  const CustomTextButton({
    super.key,
    this.textColor,
    required this.buttonText,
    required this.buttonAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: buttonAction,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? const Color(0xFF00BFFF), // Cor mais suave
      ),
      child: Text(
        buttonText,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}