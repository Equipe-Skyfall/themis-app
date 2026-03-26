import 'package:flutter/material.dart';

import '../ui/app_bar.dart';
import '../ui/precedent_sheet.dart';
import '../../lib/models.dart';

class ResultsPage extends StatelessWidget {
  final CaseHistory case_;
  final List<Precedent> precedents;
  final VoidCallback onBack;

  const ResultsPage({
    super.key,
    required this.case_,
    required this.precedents,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Resultados',
        onBack: onBack,
        showSettings: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUMO DO CASO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    case_.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris ante nunc, ullamcorper a lorem vitae, consectetur gravida felis. Sed vitae eros molestie phasellus sollicitudin volutpat felis. Phasellus fringilla faucibus eros vestibatis tellus sed tiled venenatis, luctus sem sit amet, volutpat pharetra tortor sit sed sodales. Sed tiled venenatis, luctus sem sit amet, volutpat amet, mattis nec eg',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Precedentes Encontrados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 12),

            ...precedents.map((precedent) {
              return _PrecedentCard(
                precedent: precedent,
                onTap: () => showPrecedentSheet(context, precedent),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _PrecedentCard extends StatelessWidget {
  final Precedent precedent;
  final VoidCallback onTap;

  const _PrecedentCard({required this.precedent, required this.onTap});

  Color _getSimilarityColor(double similarity) {
    if (similarity >= 80) {
      return Colors.green;
    } else if (similarity >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applicable':
        return const Color(0xFF4CAF50);
      case 'preliminary':
        return const Color(0xFFF9A825);
      case 'not_applicable':
        return const Color(0xFFD94841);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'applicable':
        return 'Aplicável';
      case 'possibly_applicable':
      case 'preliminary':
        return 'Possivelmente Aplicável';
      case 'not_applicable':
        return 'Não Aplicável';
      default:
        return 'Desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        precedent.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E2C),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        precedent.tribunal,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getSimilarityColor(
                      precedent.similarity,
                    ).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${precedent.similarity.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getSimilarityColor(precedent.similarity),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              precedent.theme,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(precedent.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getStatusLabel(precedent.status),
                style: TextStyle(
                  color: _getStatusColor(precedent.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
