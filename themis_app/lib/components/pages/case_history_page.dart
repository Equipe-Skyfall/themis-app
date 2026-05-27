import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../../hooks/use_judge_case_history_controller.dart';
import '../../lib/models.dart';
import '../ui/app_bar.dart';

class CaseHistoryPage extends HookWidget {
  final String? token;
  final void Function(HistoryEntry entry)? onSelectHistory;
  final VoidCallback onBack;

  const CaseHistoryPage({
    super.key,
    this.token,
    this.onSelectHistory,
    required this.onBack,
  });

  static const Color _primary = Color(0xFF1D2A7A);
  static const Color _background = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    final judgeHistory = useJudgeCaseHistoryController(token: token);

    return Scaffold(
      backgroundColor: _background,
      appBar: CustomAppBar(
        title: 'HISTÓRICO DE PROCESSOS',
        showSettings: false,
        onBack: onBack,
      ),
      body: RefreshIndicator(
        onRefresh: judgeHistory.refresh,
        child: judgeHistory.isLoading && judgeHistory.entries.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : judgeHistory.entries.isEmpty
                ? _EmptyState(
                    onBack: onBack,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: judgeHistory.entries.length,
                    itemBuilder: (context, index) {
                      final entry = judgeHistory.entries[index];
                      return _CaseHistoryCard(
                        entry: entry,
                        onTap: () => onSelectHistory?.call(entry),
                      );
                    },
                  ),
      ),
    );
  }
}

class _CaseHistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _CaseHistoryCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormatter.format(entry.timestamp);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título do processo
              Text(
                entry.filename,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E2C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Resumo do caso (se disponível)
              if (entry.summary != null && entry.summary!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.summary!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Rodapé com data e ícone
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;

  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum processo analisado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comece analisando um novo processo\npara visualizar o histórico aqui',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.add),
              label: const Text('Analisar Novo Processo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D2A7A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
