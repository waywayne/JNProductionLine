import 'package:flutter/material.dart';

class FileLoaderSection extends StatelessWidget {
  final String title;
  final String path;
  final VoidCallback onLoad;

  const FileLoaderSection({
    super.key,
    required this.title,
    required this.path,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              height: 32,
              child: ElevatedButton(
                onPressed: onLoad,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Load',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  path,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
