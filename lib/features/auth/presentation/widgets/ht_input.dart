import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class HtInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final bool autofocus;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const HtInput({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.autofocus = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkBody,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofocus: autofocus,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: placeholder,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
