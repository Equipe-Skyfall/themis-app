import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../ui/app_bar.dart';
import '../ui/footer_navbar.dart';
import '../../hooks/use_history_controller.dart';
import '../../lib/models.dart';
import '../../lib/profile_mode.dart';

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
        // TODO: Implementar exportação para PDF quando o backend estiver pronto
        await Future.delayed(const Duration(seconds: 1));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funcionalidade de exportação em desenvolvimento')),
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
                            'Minuta de Sentença',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E1E2C),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selecione um caso para visualizar',
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
                if (selectedEntry.value != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E2C),
                          const Color(0xFF1E1E2C).withOpacity(0.9),
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
                  _buildSection(
                    title: 'RELATÓRIO',
                    content:
                        'Análise do caso: ${selectedEntry.value!.filename}\n\n'
                        'Data da análise: ${_formatDate(selectedEntry.value!.timestamp)}\n\n'
                        'Precedentes encontrados: ${selectedEntry.value!.precedents.length}\n\n'
                        'Este relatório apresenta a síntese da análise realizada sobre o caso em questão.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'FUNDAMENTAÇÃO',
                    content: _generateFundamentacao(selectedEntry.value!),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'ANÁLISE DE ADERÊNCIA/DISTINÇÃO',
                    content: _generateAderencia(selectedEntry.value!),
                  ),
                  const SizedBox(height: 20),
                  _buildDispositivoSection(selectedEntry.value!),
                  const SizedBox(height: 20),
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
                          style: const TextStyle(fontSize: 12, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Juiz(a) de Direito',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Selecione um caso para visualizar a minuta de sentença',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  static String _generateFundamentacao(HistoryEntry entry) =>
      '''A fundamentação baseia-se na análise detalhada de ${entry.precedents.length} precedentes relevantes encontrados pela inteligência artificial.

Os precedentes identificados apresentam forte correlação com o caso em tela, fornecendo sólida base jurisprudencial para a decisão.

A análise considera jurisprudência consolidada, doutrina dominante e os princípios constitucionais aplicáveis.''';

  static String _generateAderencia(HistoryEntry entry) {
    final aplicaveis = entry.precedents.where((p) => p.status == 'applicable').length;
    final possiveis = entry.precedents.where((p) => p.status == 'preliminary' || p.status == 'possibly_applicable').length;
    final nao = entry.precedents.length - aplicaveis - possiveis;

    return '''Análise Comparativa de Precedentes:

✓ Precedentes Aplicáveis: $aplicaveis
✓ Precedentes Possivelmente Aplicáveis: $possiveis
✓ Precedentes Não Aplicáveis: $nao

A ponderação destes casos permite identificar o entendimento jurisprudencial predominante.''';
  }

  static Widget _buildDispositivoSection(HistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E2C).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1E2C).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DISPOSITIVO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '''Pelos fundamentos expostos sobre "${entry.filename}", DECIDO:

I. Acolher as argumentações fundamentadas nos ${entry.precedents.length} precedentes analisados.

II. Aplicar os entendimentos jurisprudenciais consolidados ao caso em tela.

III. Determinar o prosseguimento conforme as normas legais pertinentes.

IV. Condenar ao pagamento das custas processuais e honorários advocatícios.

V. Esta sentença pode ser objeto de recurso ordinário no prazo legal.''',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSection({required String title, required String content}) {
    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
