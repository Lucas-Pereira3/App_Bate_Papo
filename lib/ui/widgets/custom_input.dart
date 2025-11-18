import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType keyboardType;
  final bool enabled;
  final Widget? suffixIcon; 
  final TextStyle? hintStyle;

  const CustomInput({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.suffixIcon, 
    this.hintStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[200], 
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0), 
          borderSide: BorderSide.none, 
        ),
        enabledBorder: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Color(0xFF00BFFF),
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        
        suffixIcon: suffixIcon, 
      ),
    );
  }
}