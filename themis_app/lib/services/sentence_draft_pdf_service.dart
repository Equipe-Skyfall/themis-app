import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../lib/models.dart';

class SentenceDraftPdfService {
  static const _primaryColor = PdfColor.fromInt(0xFF1D2A7A);
  static const _textColor = PdfColor.fromInt(0xFF1E1E2C);
  static const _greyColor = PdfColor.fromInt(0xFF74839A);
  static const _greyLight = PdfColor.fromInt(0xFFE8EAED);
  static const _primaryLight = PdfColor.fromInt(0xFFF0F2FF);
  static const _borderColor = PdfColor.fromInt(0xFFE0E0E0);
  static const _darkColor = PdfColor.fromInt(0xFF1E1E2C);

  static Future<String> exportSentenceDraftToPdf(HistoryEntry entry) async {
    // Gerar bytes do PDF
    final pdfBytes = await _generatePdfBytes(entry);

    // Gerar nome sugerido
    final suggestedFilename = _generateFilename(entry);

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

  static Future<Uint8List> _generatePdfBytes(HistoryEntry entry) async {
    final pdf = pw.Document();

    final minuta = entry.minuta ?? '';
    final paragraphs = minuta.isNotEmpty
        ? minuta.split('\n')
        : ['Minuta não disponível para este caso.'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildHeader(entry),
        footer: (context) => _buildFooter(context),
        build: (context) {
          return [
            // MINUTA DE DECISÃO (conteúdo real da IA)
            ...paragraphs.map((line) {
              if (line.trim().isEmpty) return pw.SizedBox(height: 8);

              if (line.startsWith('## ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
                  child: pw.Text(
                    line.substring(3).replaceAll('**', ''),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                );
              }

              if (line.startsWith('# ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
                  child: pw.Text(
                    line.substring(2).replaceAll('**', ''),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                );
              }

              if (line.startsWith('### ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                  child: pw.Text(
                    line.substring(4).replaceAll('**', ''),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                );
              }

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  line.replaceAll('**', '').replaceAll('*', ''),
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: _textColor,
                    height: 1.5,
                  ),
                ),
              );
            }),
            pw.SizedBox(height: 40),

            // ASSINATURA
            pw.Column(
              children: [
                pw.SizedBox(height: 50),
                pw.Text('_' * 50, style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 5),
                pw.Text('Juiz(a) de Direito',
                    style: pw.TextStyle(fontSize: 10, color: _greyColor)),
              ],
            ),
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
        dialogTitle: 'Salvar Minuta de Sentença',
        fileName: suggestedFilename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        initialDirectory: initialPath,
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  static pw.Widget _buildHeader(HistoryEntry entry) {
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
            'MINUTA DE SENTENÇA',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 1,
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
                    entry.filename,
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
                    'Data:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _formatDate(entry.timestamp),
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
                    'Precedentes:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    entry.precedents.length.toString(),
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

  static pw.Widget _buildFooter(pw.Context context) {
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
            'THEMIS - Sistema de Análise de Precedentes',
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

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  static String _generateFilename(HistoryEntry entry) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final title = entry.filename.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'Minuta_${title}_$dateStr.pdf';
  }
}
