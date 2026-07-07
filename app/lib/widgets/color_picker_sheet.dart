import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Returns hex string like "#D1483A", or null if user picked "clear".
Future<String?> showColorPickerSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tag color',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: AppColors.tagPalette.map((c) {
                  final hex =
                      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
                  final selected = current == hex;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, hex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.navyDeep, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Clear color',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        ),
      );
    },
  );
}