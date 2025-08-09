import 'package:flutter/material.dart';

class TablaEdificiosAulas extends StatelessWidget {
  final Map<String, List<String>> edificiosAulas;

  const TablaEdificiosAulas({super.key, required this.edificiosAulas});

  @override
  Widget build(BuildContext context) {
    if (edificiosAulas.isEmpty) {
      return Center(
        child: Text(
          'No hay información de edificios y aulas disponible.',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edificios y Aulas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF193863),
            ),
          ),
          const SizedBox(height: 10),
          ...edificiosAulas.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                '${entry.key}: ${entry.value.join(", ")}',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }),
        ],
      ),
    );
  }
}