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
            const Text(
              'Precedentes Encontrados',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 18),

            ...precedents.map((precedent) {
              return _PrecedentCard(
                precedent: precedent,
                onTap: () => showPrecedentSheet(context, precedent),
              );
            }).toList(),

            if (precedents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  'Nenhum precedente encontrado para este arquivo.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
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

  static const _similarityColor = Color(0xFF1D2A7A);

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

  Color _getStatusBackground(String status) {
    return _getStatusColor(status).withOpacity(0.12);
  }

  String _buildMeta() {
    final normalizedStatus = _normalize(_getStatusLabel(precedent.status));
    final legal = precedent.legalStatus.trim();
    if (legal.isEmpty || _normalize(legal) == normalizedStatus) {
      return precedent.tribunal;
    }
    return '${precedent.tribunal} · $legal';
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E2C),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildMeta(),
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF74839A),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${precedent.similarity.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _similarityColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      'similaridade',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              precedent.theme,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5F728D),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBackground(precedent.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusLabel(precedent.status),
                    style: TextStyle(
                      color: _getStatusColor(precedent.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
