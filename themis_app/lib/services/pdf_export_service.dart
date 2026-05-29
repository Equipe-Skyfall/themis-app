import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:themis_app/lib/models.dart';

/// Dados de um precedente para exportação completa (Frente 1).
class PrecedentExportData {
  final Precedent precedent;
  final bool includeTese;

  const PrecedentExportData({
    required this.precedent,
    this.includeTese = true,
  });
}

class PDFExportService {
  static const _primaryColor = PdfColor.fromInt(0xFF1D2A7A); // Azul Themis
  static const _textColor = PdfColor.fromInt(0xFF1E1E2C);
  static const _greyColor = PdfColor.fromInt(0xFF74839A);
  static const _greyLight = PdfColor.fromInt(0xFFE8EAED);
  static const _successColor = PdfColor.fromInt(0xFF4CAF50);
  static const _warningColor = PdfColor.fromInt(0xFFF9A825);
  static const _errorColor = PdfColor.fromInt(0xFFD94841);
  static const _primaryLight = PdfColor.fromInt(0xFFF0F2FF); // Azul muito claro
  static const _borderColor = PdfColor.fromInt(0xFFE0E0E0);

  /// Exporta a petição gerada (Frente 1) para PDF com header THEMIS e formatação completa.
  static Future<String> exportPetitionToPdf({
    required String petitionText,
    required String caseDescription,
  }) async {
    final cleanText = _sanitizeForPdf(petitionText);
    final cleanDesc = _sanitizeForPdf(caseDescription);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: pw.BoxDecoration(
                color: _primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'THEMIS',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Assistente Juridico - Peticao Gerada',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            if (cleanDesc.trim().isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: _primaryColor, width: 4),
                  ),
                  color: PdfColor.fromInt(0xFFF5F7FF),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DESCRICAO DO CASO',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      cleanDesc,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: PdfColor.fromInt(0xFF3A3A4A),
                      ),
                      maxLines: 4,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
            pw.Divider(color: _borderColor),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _borderColor)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Gerado pelo Themis — Assistente Juridico',
                style: pw.TextStyle(fontSize: 8, color: _greyColor),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: _greyColor),
              ),
            ],
          ),
        ),
        build: (context) {
          final paragraphs = cleanText.split('\n');
          return paragraphs.map((p) {
            if (p.trim().isEmpty) return pw.SizedBox(height: 8);
            return _buildMarkdownParagraph(p);
          }).toList();
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName =
        'Themis_Peticao_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final downloadsDir = await getDownloadsDirectory();
    final defaultPath =
        downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

    final selectedPath = await _showSaveDialog(fileName, defaultPath);
    if (selectedPath == null) {
      throw Exception('Salvamento cancelado pelo usuario');
    }

    final file = File(selectedPath);
    await file.writeAsBytes(pdfBytes);
    return selectedPath;
  }

  /// Exporta PDF completo com seleção: petição opcional + precedentes selecionados com/sem tese.
  static Future<String> exportComprehensivePetitionPdf({
    required String caseDescription,
    String? petitionText,
    required List<PrecedentExportData> precedents,
  }) async {
    final cleanDesc = _sanitizeForPdf(caseDescription);
    final cleanPetition =
        petitionText != null ? _sanitizeForPdf(petitionText) : null;

    String _statusLabel(String status) {
      switch (status) {
        case 'applicable':
          return 'Aplicavel';
        case 'not_applicable':
          return 'Nao Aplicavel';
        default:
          return 'Possivelmente Aplicavel';
      }
    }

    PdfColor _statusColor(String status) {
      switch (status) {
        case 'applicable':
          return const PdfColor.fromInt(0xFF4CAF50);
        case 'not_applicable':
          return const PdfColor.fromInt(0xFFD94841);
        default:
          return const PdfColor.fromInt(0xFFF9A825);
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header THEMIS
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: pw.BoxDecoration(
                color: _primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'THEMIS',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Assistente Juridico - Relatorio Completo',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            // Descrição do caso
            if (cleanDesc.trim().isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: _primaryColor, width: 4),
                  ),
                  color: PdfColor.fromInt(0xFFF5F7FF),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DESCRICAO DO CASO',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      cleanDesc,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: PdfColor.fromInt(0xFF3A3A4A),
                      ),
                      maxLines: 4,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
            pw.Divider(color: _borderColor),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _borderColor)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Gerado pelo Themis - Assistente Juridico',
                style: pw.TextStyle(fontSize: 8, color: _greyColor),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: _greyColor),
              ),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          // ── Seção: Petição Gerada ──
          if (cleanPetition != null && cleanPetition.trim().isNotEmpty) {
            widgets.add(pw.Text(
              'PETICAO GERADA',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
                letterSpacing: 0.5,
              ),
            ));
            widgets.add(pw.SizedBox(height: 8));
            for (final line in cleanPetition.split('\n')) {
              if (line.trim().isEmpty) {
                widgets.add(pw.SizedBox(height: 8));
              } else {
                widgets.add(_buildMarkdownParagraph(line));
              }
            }
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Divider(color: _borderColor));
            widgets.add(pw.SizedBox(height: 16));
          }

          // ── Seção: Precedentes ──
          if (precedents.isNotEmpty) {
            widgets.add(pw.Text(
              'PRECEDENTES ENCONTRADOS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
                letterSpacing: 0.5,
              ),
            ));
            widgets.add(pw.SizedBox(height: 12));

            for (int i = 0; i < precedents.length; i++) {
              final data = precedents[i];
              final p = data.precedent;
              final statusLabel = _statusLabel(p.status);
              final statusClr = _statusColor(p.status);
              final cleanSummary = _sanitizeForPdf(p.summary);
              final cleanTese = _sanitizeForPdf(p.thesis);

              widgets.add(
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _borderColor),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Título + similaridade
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${i + 1}. ${_sanitizeForPdf(p.title)}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                          ),
                          pw.Text(
                            '${p.similarity.toStringAsFixed(0)}%',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      // Tribunal + badge status
                      pw.Row(
                        children: [
                          pw.Text(
                            _sanitizeForPdf(p.tribunal),
                            style: pw.TextStyle(fontSize: 10, color: _greyColor),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: PdfColor(
                                statusClr.red,
                                statusClr.green,
                                statusClr.blue,
                                0.15,
                              ),
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(12)),
                              border: pw.Border.all(color: statusClr, width: 0.5),
                            ),
                            child: pw.Text(
                              statusLabel,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: statusClr,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      // Resumo/enunciado
                      if (cleanSummary.trim().isNotEmpty) ...[
                        pw.Text(
                          'ENUNCIADO',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _greyColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          cleanSummary,
                          style: const pw.TextStyle(
                              fontSize: 10, height: 1.4,
                              color: PdfColor.fromInt(0xFF3A3A4A)),
                        ),
                      ],
                      // Tese (opcional)
                      if (data.includeTese && cleanTese.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'TESE',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _greyColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          cleanTese,
                          style: pw.TextStyle(
                            fontSize: 10,
                            height: 1.4,
                            color: _primaryColor,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName =
        'Themis_Relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final downloadsDir = await getDownloadsDirectory();
    final defaultPath =
        downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

    final selectedPath = await _showSaveDialog(fileName, defaultPath);
    if (selectedPath == null) {
      throw Exception('Salvamento cancelado pelo usuario');
    }

    final file = File(selectedPath);
    await file.writeAsBytes(pdfBytes);
    return selectedPath;
  }

  static Future<String> exportMinutaToPdf(String minuta) async {
    // Comprehensive sanitization for PDF font compatibility
    var cleanText = _sanitizeForPdf(minuta);

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
    final fileName = 'Themis_Minuta_${DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '')}.pdf';
    final downloadsDir = await getDownloadsDirectory();
    final defaultPath = downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

    final selectedPath = await _showSaveDialog(fileName, defaultPath);

    if (selectedPath == null) {
      throw Exception('Salvamento cancelado pelo usuario');
    }

    final file = File(selectedPath);
    await file.writeAsBytes(pdfBytes);

    return selectedPath;
  }

  static Future<String> savePdfToDownloads(pw.Document pdf, String fileName) async {
    try {
      final pdfBytes = await pdf.save();
      final downloadsDir = await getDownloadsDirectory();
      final defaultPath = downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

      final selectedPath = await _showSaveDialog(fileName, defaultPath);

      if (selectedPath == null) {
        throw Exception('Salvamento cancelado pelo usuário');
      }

      final file = File(selectedPath);
      await file.writeAsBytes(pdfBytes);

      return selectedPath;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> exportPrecedentsToPdf(
    List<Precedent> precedents,
    CaseHistory caseHistory,
    String? summary,
  ) async {
    // Gerar bytes do PDF
    final pdfBytes = await _generatePdfBytes(precedents, caseHistory, summary);

    // Gerar nome sugerido
    final suggestedFilename = _generateFilename(caseHistory);

    // Obter diretório padrão para sugerir ao usuário
    final downloadsDir = await getDownloadsDirectory();
    final defaultPath = downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

    // Abrir diálogo de salvamento
    final selectedPath = await _showSaveDialog(suggestedFilename, defaultPath);

    if (selectedPath == null) {
      throw Exception('Salvamento cancelado pelo usuário');
    }

    // Salvar o arquivo no local escolhido
    final file = File(selectedPath);
    await file.writeAsBytes(pdfBytes);

    return selectedPath;
  }

  static Future<Uint8List> _generatePdfBytes(
    List<Precedent> precedents,
    CaseHistory caseHistory,
    String? summary,
  ) async {
    final pdf = pw.Document();

    // Calcular número de precedentes
    final totalPrecedents = precedents.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildHeader(caseHistory),
        footer: (context) => _buildFooter(context, totalPrecedents),
        build: (context) {
          return [
            // Seção de resumo
            if (summary != null && summary.trim().isNotEmpty) ...[
              _buildSummarySection(summary),
              pw.SizedBox(height: 20),
            ],

            // Seção de precedentes
            _buildPrecedentsHeader(),
            pw.SizedBox(height: 10),
            ...precedents.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final precedent = entry.value;
              return pw.Column(
                children: [
                  _buildPrecedentCard(precedent, index),
                  pw.SizedBox(height: 12),
                ],
              );
            }).toList(),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static Future<String?> _showSaveDialog(
    String suggestedFilename,
    String initialPath,
  ) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar PDF de Precedentes',
        fileName: suggestedFilename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        initialDirectory: initialPath,
      );

      return result;
    } catch (e) {
      // Em caso de erro, retornar null para que o usuário possa tentar novamente
      return null;
    }
  }

  static pw.Widget _buildHeader(CaseHistory caseHistory) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'THEMIS',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Análise de Precedentes Jurídicos',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.normal,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Caso:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    caseHistory.title,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Data:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    caseHistory.date,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Status:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    caseHistory.status,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(String summary) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: _primaryLight,
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMO DO CASO',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            summary,
            style: pw.TextStyle(
              fontSize: 10,
              color: _textColor,
              height: 1.5,
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPrecedentsHeader() {
    return pw.Text(
      'PRECEDENTES ENCONTRADOS',
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: _textColor,
      ),
    );
  }

  static pw.Widget _buildPrecedentCard(Precedent precedent, int index) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabeçalho do card com número e similaridade
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '#$index - ${precedent.title}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _textColor,
                  height: 1.2,
                ),
              ),
              pw.Text(
                '${precedent.similarity.toStringAsFixed(0)}%',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Tribunal e status
          pw.Text(
            precedent.tribunal,
            style: pw.TextStyle(
              fontSize: 10,
              color: _greyColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),

          // Badges de status e situação
          pw.Row(
            children: [
              _buildStatusBadge(precedent.status),
              pw.SizedBox(width: 8),
              pw.Flexible(
                child: pw.Text(
                  precedent.situacao,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _primaryColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Tema
          _buildInfoField('Tema:', precedent.theme),
          pw.SizedBox(height: 8),

          // Explicação
          _buildInfoField('Explicação:', _sanitizeText(precedent.whyApplies)),
          pw.SizedBox(height: 8),

          // Tese Firmada
          _buildInfoField('Tese Firmada:', _sanitizeText(precedent.thesis)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatusBadge(String status) {
    late PdfColor bgColor;
    late PdfColor textColor;
    late String label;

    switch (status) {
      case 'applicable':
        bgColor = PdfColor.fromInt(0xFFC8E6C9); // Verde claro
        textColor = _successColor;
        label = 'Aplicável';
        break;
      case 'possibly_applicable':
      case 'preliminary':
        bgColor = PdfColor.fromInt(0xFFFFE0B2); // Laranja claro
        textColor = _warningColor;
        label = 'Possivelmente Aplicável';
        break;
      case 'not_applicable':
        bgColor = PdfColor.fromInt(0xFFFFCDD2); // Vermelho claro
        textColor = _errorColor;
        label = 'Não Aplicável';
        break;
      default:
        bgColor = _greyLight;
        textColor = _greyColor;
        label = 'Desconhecido';
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isEmpty ? 'Não informado' : value,
          style: pw.TextStyle(
            fontSize: 9,
            color: _textColor,
            height: 1.3,
          ),
          textAlign: pw.TextAlign.justify,
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, int totalPrecedents) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderColor),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total de precedentes: $totalPrecedents',
            style: pw.TextStyle(
              fontSize: 9,
              color: _greyColor,
            ),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: _greyColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Comprehensive sanitization to ensure text only contains characters
  /// supported by the default PDF font (Latin-1 / Helvetica).
  static String _sanitizeForPdf(String input) {
    var text = input;

    // Replace common Unicode dashes with ASCII hyphen
    text = text.replaceAll('\u2014', '-');  // em dash
    text = text.replaceAll('\u2013', '-');  // en dash
    text = text.replaceAll('\u2212', '-');  // minus sign
    text = text.replaceAll('\u2010', '-');  // hyphen
    text = text.replaceAll('\u2011', '-');  // non-breaking hyphen

    // Replace smart/curly quotes with straight quotes
    text = text.replaceAll('\u201C', '"');
    text = text.replaceAll('\u201D', '"');
    text = text.replaceAll('\u201E', '"');
    text = text.replaceAll('\u2018', "'");
    text = text.replaceAll('\u2019', "'");
    text = text.replaceAll('\u201A', "'");

    // Replace bullets and special list markers
    text = text.replaceAll('\u2022', '-');
    text = text.replaceAll('\u2023', '-');
    text = text.replaceAll('\u25E6', '-');
    text = text.replaceAll('\u2043', '-');

    // Replace ellipsis
    text = text.replaceAll('\u2026', '...');

    // Replace spaces
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\u2003', ' ');
    text = text.replaceAll('\u2002', ' ');
    text = text.replaceAll('\u2009', ' ');
    text = text.replaceAll('\u200B', '');
    text = text.replaceAll('\uFEFF', '');

    // Replace other common symbols
    text = text.replaceAll('\u2192', '->');
    text = text.replaceAll('\u2190', '<-');

    // Removed markdown stripping here so we can parse it in _buildMarkdownParagraph

    // Remove any remaining non-Latin-1 characters (codepoint > 255)
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code <= 255) {
        buffer.writeCharCode(code);
      } else {
        buffer.write(' ');
      }
    }
    text = buffer.toString();

    return text;
  }

  static pw.Widget _buildMarkdownParagraph(String text) {
    if (text.startsWith('# ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12, top: 8),
        child: pw.Text(
          text.substring(2).replaceAll('**', '').replaceAll('*', ''),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _textColor,
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
            color: _primaryColor,
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
            color: _textColor,
          ),
        ),
      );
    } else if (text.startsWith('---')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Divider(color: _borderColor),
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

  static String _sanitizeText(String input) {
    var text = input;

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Clean up whitespace
    final lines = text.split('\n').map((line) => line.trim()).toList();
    text = lines.join(' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  static Future<Directory?> _getDownloadsDirectory() async {
    try {
      // Tentar obter Downloads directory (Android, iOS, Windows, macOS)
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }

      // Fallback para Documents se Downloads não estiver disponível
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir;
    } catch (e) {
      // Se tudo falhar, usar diretório temporário
      return getTemporaryDirectory();
    }
  }

  static String _generateFilename(CaseHistory caseHistory) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final title = caseHistory.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'Themis_${title}_$dateStr.pdf';
  }
}
