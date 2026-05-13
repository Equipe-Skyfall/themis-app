import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:themis_app/lib/models.dart';

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
