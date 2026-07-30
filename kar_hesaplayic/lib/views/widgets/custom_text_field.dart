import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? suffixText;
  final String? prefixText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool isNumeric;
  final String? hint;

  /// true ise yazarken canlı binlik ayraç eklenir (örn. 12.500).
  /// Tutar alanları için true, oran/saat gibi küçük sayılar için false önerilir.
  final bool useThousandsSeparator;

  const CustomTextField({
    super.key,
    required this.label,
    this.suffixText,
    this.prefixText,
    this.controller,
    this.onChanged,
    this.isNumeric = true,
    this.hint,
    this.useThousandsSeparator = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: AppTextStyles.bodyBold(context)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            keyboardType: widget.isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: widget.isNumeric
                ? [
                    if (widget.useThousandsSeparator)
                      ThousandsSeparatorInputFormatter()
                    else
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ]
                : null,
            style: AppTextStyles.bodyBold(context),
            decoration: InputDecoration(
              hintText: widget.hint ?? '0',
              prefixText: widget.prefixText,
              suffixText: widget.suffixText,
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Temizle',
                      onPressed: _clear,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
