import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../ui/app_bar.dart';
import '../ui/precedent_sheet.dart';
import '../../lib/models.dart';
import '../../services/pdf_export_service.dart';

class ResultsPage extends StatefulWidget {
  final CaseHistory case_;
  final List<Precedent> precedents;
  final String? summary;
  final Map<String, dynamic>? analysisData;
  final VoidCallback onBack;

  const ResultsPage({
    super.key,
    required this.case_,
    required this.precedents,
    this.summary,
    this.analysisData,
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

  bool _hasOnlyWeakPrecedents() {
    if (widget.precedents.isEmpty) {
      return false;
    }
    return !widget.precedents.any((p) => 
      _normalizeStatus(p.status) == 'applicable'
    );
  }

  Widget _buildWeakPrecedentsAlert() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF9A825),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atenção: Sem precedentes fortes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nenhum precedente com alta relevância foi encontrado. '
                  'Os resultados abaixo podem ter baixa similaridade. '
                  'Recomendamos revisar com cautela.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _showMinutaBottomSheet(BuildContext context) {
    final minuta = widget.analysisData?['minuta'] ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Minuta de Sentença',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2C),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _exportMinutaToPdf(minuta),
                          icon: const Icon(Icons.download_rounded),
                          tooltip: 'Download PDF',
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: MarkdownBody(
                    data: minuta,
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2C),
                      ),
                      h2: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D2A7A),
                      ),
                      h3: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E2C),
                      ),
                      p: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3A3A4A),
                        height: 1.6,
                      ),
                      strong: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2C),
                      ),
                      em: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF3A3A4A),
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.grey[100],
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                      blockquote: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3A3A4A),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sanitize text to only contain characters supported by the default PDF font (Latin-1).
  String _sanitizeForPdf(String input) {
    var text = input;

    // Replace common Unicode dashes with ASCII hyphen
    text = text.replaceAll('\u2014', '-');  // em dash —
    text = text.replaceAll('\u2013', '-');  // en dash –
    text = text.replaceAll('\u2212', '-');  // minus sign −
    text = text.replaceAll('\u2010', '-');  // hyphen ‐
    text = text.replaceAll('\u2011', '-');  // non-breaking hyphen ‑

    // Replace smart/curly quotes with straight quotes
    text = text.replaceAll('\u201C', '"');  // left double "
    text = text.replaceAll('\u201D', '"');  // right double "
    text = text.replaceAll('\u201E', '"');  // double low „
    text = text.replaceAll('\u2018', "'"); // left single '
    text = text.replaceAll('\u2019', "'"); // right single '
    text = text.replaceAll('\u201A', "'"); // single low ‚

    // Replace bullets and special list markers
    text = text.replaceAll('\u2022', '-');  // bullet •
    text = text.replaceAll('\u2023', '-');  // triangular bullet ‣
    text = text.replaceAll('\u25E6', '-');  // white bullet ◦
    text = text.replaceAll('\u2043', '-');  // hyphen bullet ⁃

    // Replace ellipsis
    text = text.replaceAll('\u2026', '...');  // …

    // Replace spaces
    text = text.replaceAll('\u00A0', ' ');  // non-breaking space
    text = text.replaceAll('\u2003', ' ');  // em space
    text = text.replaceAll('\u2002', ' ');  // en space
    text = text.replaceAll('\u2009', ' ');  // thin space
    text = text.replaceAll('\u200B', '');   // zero-width space
    text = text.replaceAll('\uFEFF', '');   // BOM

    // Replace other common symbols
    text = text.replaceAll('\u00B0', 'o');  // degree symbol ° -> o (for nº usage)
    text = text.replaceAll('\u2192', '->'); // right arrow →
    text = text.replaceAll('\u2190', '<-'); // left arrow ←

    // Removed markdown stripping here so we can parse it in _buildMarkdownParagraph

    // Remove any remaining non-Latin-1 characters (codepoint > 255)
    // but preserve accented Portuguese characters which ARE in Latin-1
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code <= 255) {
        buffer.writeCharCode(code);
      } else {
        buffer.write(' '); // replace unknown chars with space
      }
    }
    text = buffer.toString();

    return text;
  }

  pw.Widget _buildMarkdownParagraph(String text) {
    if (text.startsWith('# ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12, top: 8),
        child: pw.Text(
          text.substring(2).replaceAll('**', '').replaceAll('*', ''),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1E1E2C),
          ),
        ),
      );
    } else if (text.startsWith('## ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10, top: 6),
        child: pw.Text(
          text.substring(3).replaceAll('**', '').replaceAll('*', ''),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1D2A7A), // Azul Themis
          ),
        ),
      );
    } else if (text.startsWith('### ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
        child: pw.Text(
          text.substring(4).replaceAll('**', '').replaceAll('*', ''),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1E1E2C),
          ),
        ),
      );
    } else if (text.startsWith('---')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Divider(color: const PdfColor.fromInt(0xFFE0E0E0)),
      );
    }

    final spans = <pw.InlineSpan>[];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      
      // Clean up remaining single asterisks
      final textPart = parts[i].replaceAll('*', '');
      if (textPart.isEmpty) continue;
      
      if (i % 2 == 1) {
        // Bold
        spans.add(pw.TextSpan(
          text: textPart,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ));
      } else {
        // Normal
        spans.add(pw.TextSpan(text: textPart));
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: const pw.TextStyle(
            fontSize: 10,
            height: 1.5,
          ),
          children: spans,
        ),
      ),
    );
  }

  Future<void> _exportMinutaToPdf(String minuta) async {
    try {
      setState(() => _isExporting = true);

      final cleanText = _sanitizeForPdf(minuta);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            final paragraphs = cleanText.split('\n');
            return [
              pw.Text(
                'MINUTA DE SENTENCA',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              ...paragraphs.map((p) {
                if (p.trim().isEmpty) return pw.SizedBox(height: 10);
                return _buildMarkdownParagraph(p);
              }),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'Themis_Minuta_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final downloadsDir = await getDownloadsDirectory();
      final defaultPath = downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Minuta de Sentenca',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        initialDirectory: defaultPath,
      );

      if (selectedPath == null) {
        return;
      }

      final file = File(selectedPath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvo: ${selectedPath.split('\\').last}'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: const Color(0xFFD94841),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
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

            // ── MINUTA DE SENTENÇA ──
            if (widget.analysisData != null && widget.analysisData!['minuta'] != null)
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
                child: InkWell(
                  onTap: () => _showMinutaBottomSheet(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D2A7A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Color(0xFF1D2A7A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Minuta de Sentença',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1E2C),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Visualizar sentença gerada pela IA',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF74839A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF74839A),
                        ),
                      ],
                    ),
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

            // ── ALERTA DE PRECEDENTES FRACOS ──
            if (_hasOnlyWeakPrecedents() && _selectedApplicability.isEmpty)
              _buildWeakPrecedentsAlert(),

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
