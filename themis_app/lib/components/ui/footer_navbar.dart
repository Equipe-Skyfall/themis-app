import 'package:flutter/material.dart';

class FooterNavbar extends StatelessWidget {
  /// Callback para voltar ao Dashboard
  final VoidCallback onDashboard;

  /// Callback para acessar minuta de sentença
  final VoidCallback onSentenceDraft;

  /// Índice do botão ativo (1-5, sendo 3 o central)
  final int activeIndex;

  const FooterNavbar({
    super.key,
    required this.onDashboard,
    required this.onSentenceDraft,
    this.activeIndex = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botão vazio esquerdo
          _NavBarButton(
            icon: Icons.file_copy_outlined,
            isActive: false,
            onTap: () {},
          ),

          // Botão vazio esquerdo-meio
          _NavBarButton(
            icon: Icons.bookmark_border,
            isActive: false,
            onTap: () {},
          ),

          // Botão central azul (Dashboard)
          _NavBarButton(
            icon: Icons.add,
            isActive: true,
            isCenter: true,
            onTap: onDashboard,
          ),

          // Botão direita-meio (Minuta de Sentença)
          _NavBarButton(
            icon: Icons.description_outlined,
            isActive: activeIndex == 4,
            onTap: onSentenceDraft,
          ),

          // Botão vazio direita
          _NavBarButton(
            icon: Icons.tune,
            isActive: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isCenter;
  final VoidCallback onTap;

  const _NavBarButton({
    required this.icon,
    required this.isActive,
    this.isCenter = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCenter
              ? const Color(0xFF1E1E2C) // Azul escuro para central
              : isActive
                  ? const Color(0xFF1E1E2C).withOpacity(0.1)
                  : Colors.grey[300],
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isCenter
              ? Colors.white
              : isActive
                  ? const Color(0xFF1E1E2C)
                  : Colors.grey[400],
          size: 22,
        ),
      ),
    );
  }
}
