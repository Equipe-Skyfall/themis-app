import 'package:flutter/material.dart';
import '../ui/app_bar.dart';
import '../ui/precedent_sheet.dart';
import '../../lib/models.dart';
import '../../services/pdf_export_service.dart';

class ResultsPage extends StatefulWidget {
  final CaseHistory case_;
  final List<Precedent> precedents;
  final String? summary;
  final VoidCallback onBack;

  const ResultsPage({
    super.key,
    required this.case_,
    required this.precedents,
    this.summary,
    required this.onBack,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final Set<String> _selectedApplicability = <String>{};
  bool _isExporting = false;

  static const List<_ApplicabilityFilterOption> _applicabilityOptions = [
    _ApplicabilityFilterOption(
      status: 'applicable',
      label: 'Aplicável',
      color: Color(0xFF4CAF50),
    ),
    _ApplicabilityFilterOption(
      status: 'possibly_applicable',
      label: 'Possivelmente aplicável',
      color: Color(0xFFF9A825),
    ),
    _ApplicabilityFilterOption(
      status: 'not_applicable',
      label: 'Não aplicável',
      color: Color(0xFFD94841),
    ),
  ];

  List<Precedent> get _visiblePrecedents {
    if (_selectedApplicability.isEmpty) {
      return widget.precedents;
    }

    return widget.precedents.where((precedent) {
      return _selectedApplicability.contains(
        _normalizeStatus(precedent.status),
      );
    }).toList();
  }

  String _normalizeStatus(String status) {
    if (status == 'preliminary') {
      return 'possibly_applicable';
    }
    return status;
  }

  void _toggleFilter(String status) {
    setState(() {
      if (_selectedApplicability.contains(status)) {
        _selectedApplicability.remove(status);
      } else {
        _selectedApplicability.add(status);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedApplicability.clear();
    });
  }

  Future<void> _exportToPdf() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await PDFExportService.exportPrecedentsToPdf(
        _visiblePrecedents,
        widget.case_,
        widget.summary,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvo em: $filePath'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar PDF: $e'),
            backgroundColor: const Color(0xFFD94841),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePrecedents = _visiblePrecedents;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Resultados',
        onBack: widget.onBack,
        showSettings: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resultados',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
              ),
            ),
            Text(
              'Resultado de arquivos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 18),

            // ── RESUMO DO CASO ──
            if (widget.summary != null && widget.summary!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1D2A7A),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RESUMO DO CASO',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1D2A7A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.summary!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF3A3A4A),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Text(
              'Precedentes Encontrados',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filtro de aplicabilidade',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1E2C),
                          ),
                        ),
                      ),
                      if (_selectedApplicability.isNotEmpty)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedApplicability.isEmpty
                        ? 'Nenhum filtro ativo. Todos os precedentes estão visíveis.'
                        : 'Filtro(s) ativo(s): ${_selectedApplicability.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _applicabilityOptions.map((option) {
                      final selected = _selectedApplicability.contains(
                        option.status,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleFilter(option.status),
                              borderRadius: BorderRadius.circular(24),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? option.color.withOpacity(0.14)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: selected
                                        ? option.color
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      color: selected
                                          ? option.color
                                          : const Color(0xFF334155),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isExporting ? null : _exportToPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D2A7A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF1D2A7A).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Exportar para PDF',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            ...visiblePrecedents.map((precedent) {
              return _PrecedentCard(
                precedent: precedent,
                onTap: () => showPrecedentSheet(context, precedent),
              );
            }).toList(),

            if (visiblePrecedents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  _selectedApplicability.isEmpty
                      ? 'Nenhum precedente encontrado para este arquivo.'
                      : 'Nenhum precedente encontrado para o filtro selecionado.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplicabilityFilterOption {
  final String status;
  final String label;
  final Color color;

  const _ApplicabilityFilterOption({
    required this.status,
    required this.label,
    required this.color,
  });
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5EFF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    precedent.situacao,
                    style: const TextStyle(
                      color: Color(0xFF1E5EFF),
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
