import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Chip de filtre actif avec bouton de suppression (×).
/// Utilisé dans la barre de filtres horizontale.
class DismissibleFilterChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onRemove;

  const DismissibleFilterChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: textColor)),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14.sp, color: textColor),
          ),
        ],
      ),
    );
  }
}
