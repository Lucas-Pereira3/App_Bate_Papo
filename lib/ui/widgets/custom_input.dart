import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType keyboardType; // ADICIONE ESTA LINHA

  const CustomInput({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text, // VALOR PADRÃO
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
