import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../ui/app_bar.dart';
import '../../hooks/use_history_controller.dart';
import '../../lib/models.dart';

class DashboardPage extends HookWidget {
  final VoidCallback onNewAnalysis;
  final String? userName;
  final String? token;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;
  final void Function(HistoryEntry entry)? onSelectHistory;

  const DashboardPage({
    super.key,
    required this.onNewAnalysis,
    this.userName,
    this.token,
    this.onLogout,
    this.onOpenSettings,
    this.onSelectHistory,
  });

  @override
  Widget build(BuildContext context) {
    final history = useHistoryController(token: token);
    final completedCount = history.entries.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onSettings: onOpenSettings),
      body: RefreshIndicator(
        onRefresh: history.refresh,
        color: const Color(0xFF1E1E2C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo(a),',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        userName ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E2C),
                        ),
                      ),
                    ],
                  ),
                  if (onLogout != null)
                    IconButton(
                      onPressed: onLogout,
                      icon: Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.red[400],
                        size: 22,
                      ),
                      tooltip: 'Sair',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Resumo Mensal ──
              Container(
                padding: const EdgeInsets.all(20),
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
                      children: [
                        Image.asset(
                          'lib/assets/logo_transparente.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 20, height: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Resumo Mensal',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completedCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _monthLabel(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Nova Análise ──
              InkWell(
                onTap: onNewAnalysis,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nova Análise de Petição',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Encontre precedentes com IA',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Análises Recentes ──
              if (history.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                )
              else if (history.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey[400], size: 32),
                        const SizedBox(height: 8),
                        Text(
                          history.errorMessage!,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: history.refresh,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (history.entries.isNotEmpty) ...[
                const Text(
                  'Análises Recentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E2C),
                  ),
                ),
                const SizedBox(height: 12),
                ...history.entries.map((entry) {
                  return _HistoryCard(
                    entry: entry,
                    onTap: () => onSelectHistory?.call(entry),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _monthLabel() {
    final now = DateTime.now();
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return 'processos analisados em ${months[now.month - 1]}';
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(entry.timestamp);
    final countStr = '${entry.precedents.length} precedentes';

    final title = entry.filename;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr • $countStr',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
