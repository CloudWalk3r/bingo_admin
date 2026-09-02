import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Table search box with a clear affordance, sized to sit inline with the
/// filter controls above a list.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search…',
    this.width = 300,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final double width;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      width: widget.width,
      height: 44,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        cursorColor: AppTheme.primaryColor,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: _focusNode.hasFocus ? AppTheme.primaryColor : AppTheme.textTertiary,
          ),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
                  tooltip: 'Clear',
                  splashRadius: 16,
                )
              : null,
        ),
      ),
    );
  }
}

/// Segmented filter used above tables — one tap per bucket, with counts.
class FilterSegments<T> extends StatelessWidget {
  const FilterSegments({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option.value == selected;
          final tint = option.color ?? AppTheme.primaryColor;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: InkWell(
              onTap: () => onSelected(option.value),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? tint.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isSelected ? tint.withOpacity(0.45) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? tint : AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (option.count != null) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isSelected ? tint : AppTheme.textTertiary).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${option.count}',
                          style: TextStyle(
                            color: isSelected ? tint : AppTheme.textTertiary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterOption<T> {
  const FilterOption({
    required this.value,
    required this.label,
    this.count,
    this.color,
  });

  final T value;
  final String label;
  final int? count;
  final Color? color;
}
