import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryokyaku_swipe/l10n/app_localizations.dart';


class CategoryReviewModal extends StatelessWidget {
  final Map<String, int> counts;
  final Function(String) onCategorySelected;

  const CategoryReviewModal({
    super.key,
    required this.counts,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.categorySelect,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildCategoryCard(
            context,
            'all',
            l10n.allCategories,
            counts['all'] ?? 0,
            Icons.grid_view,
            Colors.grey,
          ),
          _buildCategoryCard(
            context,
            'part1',
            l10n.part1,
            counts['part1'] ?? 0,
            Icons.directions_bus,
            Colors.blueAccent,
          ),
          _buildCategoryCard(
            context,
            'part2',
            l10n.part2,
            counts['part2'] ?? 0,
            Icons.build,
            Colors.orange,
          ),
          _buildCategoryCard(
            context,
            'part3',
            l10n.part3,
            counts['part3'] ?? 0,
            Icons.traffic,
            Colors.redAccent,
          ),
          _buildCategoryCard(
            context,
            'part4',
            l10n.part4,
            counts['part4'] ?? 0,
            Icons.work_history,
            Colors.green,
          ),
          _buildCategoryCard(
            context,
            'part5',
            l10n.part5,
            counts['part5'] ?? 0,
            Icons.map,
            Colors.purple,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String id,
    String name,
    int count,
    IconData icon,
    Color color,
  ) {
    if (count == 0 && id != 'all') return const SizedBox.shrink();
    if (id == 'all' && count == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onCategorySelected(id);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.questionsCount(count),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
