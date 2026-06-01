// themis_app/lib/components/ui/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import '../../lib/profile_mode.dart';

class ThemisBottomNav extends StatelessWidget {
  final ProfileMode activeMode;

  /// Troca para a aba Advogado
  final VoidCallback onLawyer;

  /// Troca para a aba Juiz
  final VoidCallback onJudge;

  /// Abre o fluxo de nova análise (contexto depende da [activeMode])
  final VoidCallback onNewAnalysis;

  const ThemisBottomNav({
    super.key,
    required this.activeMode,
    required this.onLawyer,
    required this.onJudge,
    required this.onNewAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // ── Advogado (esquerda) ──
              Expanded(
                child: _NavItem(
                  icon: Icons.work_outline_rounded,
                  label: 'Advogado',
                  isActive: activeMode == ProfileMode.lawyer,
                  onTap: onLawyer,
                ),
              ),

              // ── FAB central — ação contextual ──
              _CenterFab(onTap: onNewAnalysis),

              // ── Juiz (direita) ──
              Expanded(
                child: _NavItem(
                  icon: Icons.gavel_rounded,
                  label: 'Juiz',
                  isActive: activeMode == ProfileMode.judge,
                  onTap: onJudge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Item lateral com indicador animado ──────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const Color _activeColor = Color(0xFF1D2A7A);
  static const Color _inactiveColor = Color(0xFF9CA3AF);

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone com fundo animado quando ativo
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? _activeColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? _activeColor : _inactiveColor,
            ),
          ),
          const SizedBox(height: 2),
          // Label animada
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? _activeColor : _inactiveColor,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 2),
          // Indicador pontinho
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            decoration: const BoxDecoration(
              color: _activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Botão "+" central elevado ───────────────────────────────────────────────

class _CenterFab extends StatelessWidget {
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1D2A7A);

  const _CenterFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
