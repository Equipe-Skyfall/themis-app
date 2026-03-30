// themis_app/lib/components/app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final bool showSettings;
  final VoidCallback? onSettings;

  const CustomAppBar({
    Key? key,
    this.title = "Themis",
    this.onBack,
    this.showSettings = true,
    this.onSettings,
  })
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      leading: onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: onBack,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/logo_transparente.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      actions: showSettings
          ? [
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_sharp, size: 20),
                tooltip: 'Configurações',
              ),
              const SizedBox(width: 4),
            ]
          : null,
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
