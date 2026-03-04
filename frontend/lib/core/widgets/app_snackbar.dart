import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppSnackbar {
  static void success(BuildContext context, String message) {
    _show(context, message, _Type.success);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, _Type.error);
  }

  static void _show(BuildContext context, String message, _Type type) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final cs = Theme.of(context).colorScheme;
    final isError = type == _Type.error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? cs.error : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }
}

enum _Type { success, error }
