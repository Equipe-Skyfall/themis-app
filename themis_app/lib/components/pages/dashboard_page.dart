import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../ui/app_bar.dart';
import '../ui/bottom_nav_bar.dart';
import '../../hooks/use_history_controller.dart';
import '../../lib/models.dart';
import '../../lib/profile_mode.dart';

class DashboardPage extends HookWidget {
  final String? userName;
  final String? token;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;
  final void Function(HistoryEntry entry)? onSelectHistory;
  final ProfileMode profileMode;
  final void Function(ProfileMode) onProfileModeChanged;

  /// Abre o fluxo de nova análise de acordo com o [profileMode] atual
  final VoidCallback onNewAnalysis;

  /// Abre o histórico completo de processos (Frente 2)
  final VoidCallback? onViewAllHistory;

  const DashboardPage({
    super.key,
    required this.profileMode,
    required this.onProfileModeChanged,
    required this.onNewAnalysis,
    this.userName,
    this.token,
    this.onLogout,
    this.onOpenSettings,
    this.onSelectHistory,
    this.onViewAllHistory,
  });

  @override
  Widget build(BuildContext context) {
    final history = useHistoryController(token: token, profileMode: profileMode);

    final activeHistory = HistoryController(
      entries: history.entries,
      isLoading: history.isLoading,
      errorMessage: history.errorMessage,
      refresh: history.refresh,
    );

    final config = _DashboardConfig.forMode(profileMode, userName);

    // ── Pagination Hooks ──
    final currentPage = useState(1);

    // Reset current page when profile mode changes
    useEffect(() {
      currentPage.value = 1;
      return null;
    }, [profileMode]);

    final itemsPerPage = 5;
    final totalItems = history.entries.length;
    final totalPages = (totalItems / itemsPerPage).ceil();
    final page = currentPage.value.clamp(1, totalPages > 0 ? totalPages : 1).toInt();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onSettings: onOpenSettings),
      bottomNavigationBar: ThemisBottomNav(
        activeMode: profileMode,
        onLawyer: () => onProfileModeChanged(ProfileMode.lawyer),
        onJudge: () => onProfileModeChanged(ProfileMode.judge),
        onNewAnalysis: onNewAnalysis,
      ),
      body: RefreshIndicator(
        onRefresh: activeHistory.refresh,
        color: const Color(0xFF1D2A7A),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _DashboardBody(
            key: ValueKey<ProfileMode>(profileMode),
            config: config,
            onLogout: onLogout,
            activeHistory: activeHistory,
            onSelectHistory: onSelectHistory,
            isJudge: profileMode == ProfileMode.judge,
            currentPage: page,
            totalPages: totalPages,
            onPageChanged: (newPage) {
              currentPage.value = newPage;
            },
            onViewAllHistory: onViewAllHistory,
          ),
        ),
      ),
    );
  }
}

// ─── Configuração visual por perfil ──────────────────────────────────────────

class _DashboardConfig {
  final String greeting;
  final String name;
  final String summaryLabel;
  final String historyTitle;
  final String emptyMessage;

  const _DashboardConfig({
    required this.greeting,
    required this.name,
    required this.summaryLabel,
    required this.historyTitle,
    required this.emptyMessage,
  });

  static _DashboardConfig forMode(ProfileMode mode, String? userName) {
    final now = DateTime.now();
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    final month = months[now.month - 1];
    final name = userName ?? 'Usuário';

    return switch (mode) {
      ProfileMode.lawyer => _DashboardConfig(
          greeting: 'Olá, Advogado(a)',
          name: name,
          summaryLabel: 'Petições analisadas em $month',
          historyTitle: 'Suas Análises Recentes',
          emptyMessage:
              'Nenhuma análise ainda.\nToque em "+" para analisar sua primeira petição.',
        ),
      ProfileMode.judge => _DashboardConfig(
          greeting: 'Olá, Excelência',
          name: name,
          summaryLabel: 'Processos analisados em $month',
          historyTitle: 'Processos Recentes',
          emptyMessage:
              'Nenhum processo ainda.\nToque em "+" para analisar o primeiro processo.',
        ),
    };
  }
}

// ─── Body isolado (para AnimatedSwitcher funcionar) ──────────────────────────

class _DashboardBody extends StatelessWidget {
  final _DashboardConfig config;
  final VoidCallback? onLogout;
  final HistoryController activeHistory;
  final void Function(HistoryEntry entry)? onSelectHistory;
  final bool isJudge;
  final int currentPage;
  final int totalPages;
  final void Function(int) onPageChanged;
  final VoidCallback? onViewAllHistory;

  const _DashboardBody({
    super.key,
    required this.config,
    required this.activeHistory,
    required this.isJudge,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.onLogout,
    this.onSelectHistory,
    this.onViewAllHistory,
  });

  @override
  Widget build(BuildContext context) {
    final count = activeHistory.entries.length;

    // ── Pagination logic ──
    final startIndex = (currentPage - 1) * 5;
    final endIndex = (startIndex + 5).clamp(0, activeHistory.entries.length).toInt();
    final pageEntries = activeHistory.entries.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saudação ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.greeting,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    config.name,
                    style: const TextStyle(
                      fontSize: 20,
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
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2A7A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isJudge ? Icons.gavel_rounded : Icons.balance_rounded,
                    color: const Color(0xFF1D2A7A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D2A7A),
                      ),
                    ),
                    Text(
                      config.summaryLabel,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Histórico ──
          if (activeHistory.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1D2A7A)),
              ),
            )
          else if (activeHistory.errorMessage != null)
            _ErrorState(
              message: activeHistory.errorMessage!,
              onRetry: activeHistory.refresh,
            )
          else if (activeHistory.entries.isEmpty)
            _EmptyState(message: config.emptyMessage)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  config.historyTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E2C),
                  ),
                ),
                if (isJudge && activeHistory.entries.isNotEmpty && onViewAllHistory != null)
                  GestureDetector(
                    onTap: onViewAllHistory,
                    child: Text(
                      'Ver tudo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2A7A),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...pageEntries.map((entry) => _HistoryCard(
                  entry: entry,
                  onTap: () => onSelectHistory?.call(entry),
                )),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: const Color(0xFF1E1E2C),
                        disabledColor: Colors.grey[300],
                        onPressed: currentPage > 1
                            ? () => onPageChanged(currentPage - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentPage de $totalPages',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E2C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: const Color(0xFF1E1E2C),
                        disabledColor: Colors.grey[300],
                        onPressed: currentPage < totalPages
                            ? () => onPageChanged(currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Estados auxiliares ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey[300], size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card do histórico ────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(entry.timestamp);
    final countStr = entry.precedents.isEmpty
        ? 'Sem precedentes'
        : '${entry.precedents.length} precedentes';

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
              color: Colors.black.withValues(alpha: 0.015),
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
                    entry.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr  •  $countStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }
}
