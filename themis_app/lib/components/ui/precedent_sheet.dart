// themis_app/lib/components/precedent_sheet.dart
import 'package:flutter/material.dart';
import 'package:themis_app/lib/models.dart';

void showPrecedentSheet(BuildContext context, Precedent precedent) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PrecedentSheetUI(precedent: precedent),
  );
}

class _PrecedentSheetUI extends StatelessWidget {
  final Precedent precedent;

  const _PrecedentSheetUI({Key? key, required this.precedent})
    : super(key: key);

  Color _getStatusColor(String status) {
    if (status == 'applicable') return Colors.green;
    if (status == 'possibly_applicable') return Colors.orange;
    return Colors.red;
  }

  String _getStatusLabel(String status) {
    if (status == 'applicable') return 'Aplicável';
    if (status == 'possibly_applicable') return 'Possivelmente Aplicável';
    return 'Não Aplicável';
  }

  Color _getStatusBackground(String status) {
    return _getStatusColor(status).withOpacity(0.12);
  }

  String _formatLegalStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'aplicavel') {
      return 'Aplicável';
    }
    if (normalized == 'nao aplicavel') {
      return 'Não Aplicável';
    }
    if (normalized == 'possivelmente aplicavel') {
      return 'Possivelmente Aplicável';
    }
    return _displayValue(value);
  }

  String _displayValue(String value, {String fallback = 'Não informado'}) {
    final sanitized = _sanitizeText(value);
    if (sanitized.isEmpty) {
      return fallback;
    }
    return sanitized;
  }

  String _sanitizeText(String input) {
    var text = input;

    // Normaliza quebras HTML para novas linhas.
    text = text.replaceAll(
      RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false),
      '\n',
    );

    // Remove outras tags HTML eventualmente vindas do backend.
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decodifica entidades HTML comuns.
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Limpa espaços extras por linha e reduz múltiplas linhas vazias.
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .toList(growable: false);

    text = lines.join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final explanationText = _displayValue(precedent.whyApplies);
    final enunciadoText = _displayValue(precedent.summary);
    final shouldShowEnunciado =
        enunciadoText.toLowerCase().trim() !=
        explanationText.toLowerCase().trim();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Text(
                  _displayValue(precedent.tribunal),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  label: _getStatusLabel(precedent.status),
                  textColor: _getStatusColor(precedent.status),
                  background: _getStatusBackground(precedent.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _displayValue(precedent.title),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${precedent.similarity.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E5EFF),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'de similaridade',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _buildField('Tema', _displayValue(precedent.theme)),
            _buildField('Status', _formatLegalStatus(precedent.legalStatus)),
            _buildField('Explicacao', explanationText),
            if (shouldShowEnunciado) _buildField('Enunciado', enunciadoText),
            _buildField('Tese Firmada', _displayValue(precedent.thesis)),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E2C).withOpacity(0.08),
                  foregroundColor: const Color(0xFF1E1E2C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Fechar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 14,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color textColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
