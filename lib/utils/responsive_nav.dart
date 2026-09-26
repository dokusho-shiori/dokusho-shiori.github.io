import 'package:flutter/material.dart';

Future<T?> pushResponsive<T>(BuildContext context, Widget screen) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 600) {
    final screenHeight = MediaQuery.of(context).size.height;
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 600,
          height: screenHeight * 0.9,
          child: screen,
        ),
      ),
    );
  }
  return Navigator.push<T>(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );
}
