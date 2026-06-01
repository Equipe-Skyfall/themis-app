import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../ui/app_bar.dart';
import '../ui/footer_navbar.dart';
import '../../hooks/use_history_controller.dart';
import 'package:themis_app/lib/models.dart';
import 'package:themis_app/lib/profile_mode.dart';
import '../../services/sentence_draft_pdf_service.dart';

class SentenceDraftPage extends HookWidget {
  final VoidCallback onBack;
  final VoidCallback onDashboard;
  final String? token;

  const SentenceDraftPage({
    super.key,
    required this.onBack,
    required this.onDashboard,
    this.token,
  });

  @override
  Widget build(BuildContext context) {
    final history = useHistoryController(token: token, profileMode: ProfileMode.judge);
    final selectedEntry = useState<HistoryEntry?>(null);
    final isExporting = useState(false);

    useEffect(() {
      if (history.entries.isNotEmpty && selectedEntry.value == null) {
        selectedEntry.value = history.entries.first;
      }
      return null;
    }, [history.entries]);

    Future<void> exportToPdf() async {
      isExporting.value = true;
      try {
        if (selectedEntry.value != null) {
          await SentenceDraftPdfService.exportSentenceDraftToPdf(selectedEntry.value!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF exportado com sucesso!')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao exportar PDF: $e')),
          );
        }
      } finally {
        isExporting.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onSettings: null),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minuta de Decisão',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E1E2C),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Visualização e exportação',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.close),
                      tooltip: 'Voltar',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Seletor de Casos
                if (history.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E1E2C),
                    ),
                  )
                else if (history.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      history.errorMessage ?? 'Erro ao carregar histórico',
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  )
                else if (history.entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'Nenhuma análise disponível. Realize uma nova análise no Dashboard.',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButton<HistoryEntry?>(
                      value: selectedEntry.value,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('Selecione um caso...'),
                      items: history.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry,
                                child: Text(
                                  entry.filename,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (entry) {
                        selectedEntry.value = entry;
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // Botão Exportar
                if (selectedEntry.value != null &&
                    selectedEntry.value!.minuta != null &&
                    selectedEntry.value!.minuta!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E2C),
                          const Color(0xFF1E1E2C).withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isExporting.value ? null : exportToPdf,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isExporting.value)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.download_outlined, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isExporting.value ? 'Exportando...' : 'Exportar em PDF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Conteúdo da Minuta
                if (selectedEntry.value != null) ...[
                  if (selectedEntry.value!.minuta != null &&
                      selectedEntry.value!.minuta!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D2A7A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MINUTA DE DECISÃO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D2A7A),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          MarkdownBody(
                            data: selectedEntry.value!.minuta!,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.6,
                              ),
                              h1: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E2C),
                              ),
                              h2: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D2A7A),
                              ),
                              h3: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E2C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'Minuta não disponível para este caso',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Este caso foi analisado antes do suporte a minutas. '
                            'Realize uma nova análise para gerar a minuta de decisão.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // Assinatura
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          '_'.padRight(60, '_'),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Juiz(a) de Direito',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Selecione um caso para visualizar a minuta de decisão',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Footer Navbar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FooterNavbar(
              activeIndex: 4,
              onDashboard: onDashboard,
              onSentenceDraft: () {},
            ),
          ),
        ],
      ),
    );
  }
}
