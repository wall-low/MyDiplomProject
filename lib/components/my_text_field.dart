import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController textEditingController;
  final String hintText;
  final bool obscureText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final String? label;

  const MyTextField({
    super.key,
    required this.textEditingController,
    required this.obscureText,
    required this.hintText,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: textEditingController,
      obscureText: obscureText,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        // Label (если есть)
        labelText: label,
        labelStyle: TextStyle(
          color: scheme.secondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),

        // Hint
        hintText: hintText,
        hintStyle: TextStyle(
          color: scheme.secondary,
          fontSize: 15,
        ),

        // Иконки
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,

        // Borders - unselected
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: scheme.secondary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),

        // Borders - selected
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),

        // Borders - error
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: scheme.error,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),

        // Error style
        errorStyle: TextStyle(
          color: scheme.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),

        // Fill
        fillColor: scheme.primaryContainer.withValues(alpha: 0.3),
        filled: true,

        // Content padding
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// Версия с анимацией и эффектами
class MyTextFieldAnimated extends StatefulWidget {
  final TextEditingController textEditingController;
  final String hintText;
  final bool obscureText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final String? label;

  const MyTextFieldAnimated({
    super.key,
    required this.textEditingController,
    required this.obscureText,
    required this.hintText,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.label,
  });

  @override
  State<MyTextFieldAnimated> createState() => _MyTextFieldAnimatedState();
}

class _MyTextFieldAnimatedState extends State<MyTextFieldAnimated> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isFocused
            ? [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: TextFormField(
        controller: widget.textEditingController,
        obscureText: widget.obscureText,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: scheme.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: scheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: scheme.secondary.withValues(alpha: 0.6),
            fontSize: 15,
          ),
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: scheme.secondary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: scheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: scheme.error,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: scheme.error,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          errorStyle: TextStyle(
            color: scheme.error,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          fillColor: scheme.surface,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}