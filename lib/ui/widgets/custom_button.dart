import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String buttonText;
  final Color backgroundColor;
  final VoidCallback buttonAction;

  const CustomButton({
    super.key,
    required this.buttonText,
    required this.backgroundColor,
    required this.buttonAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: buttonAction,
        style: ElevatedButton.styleFrom(backgroundColor: backgroundColor),
        child: Text(buttonText),
      ),
    );
  }
}
