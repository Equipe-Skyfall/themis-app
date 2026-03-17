// themis_app/lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../ui/app_bar.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNewAnalysis;
  final String? userName;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;

  const DashboardScreen({
    Key? key,
    required this.onNewAnalysis,
    this.userName,
    this.onLogout,
    this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int completedCount = mockCases.where((c) => c.status == "completed").length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onSettings: onOpenSettings),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bem-vindo(a),",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Text(
                      userName ?? "Usuário",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E2C),
                      ),
                    ),
                  ],
                ),
                if (onLogout != null)
                  TextButton(
                    onPressed: onLogout,
                    child: Text(
                      "Sair",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
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
                      SizedBox(width: 8),
                      Text(
                        "Resumo Mensal",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$completedCount",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "processos analisados em março",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: onNewAnalysis,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Nova Análise de Petição",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Encontre precedentes com IA",
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
            const SizedBox(height: 32),
            Text(
              "Análises Recentes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...mockCases
                .map(
                  (c) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      title: Text(
                        c.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "${c.date} · ${c.matchCount} precedentes",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(c.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getStatusLabel(c.status),
                              style: TextStyle(
                                color: _getStatusColor(c.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {},
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == "completed") return Colors.green;
    if (status == "pending") return Colors.orange;
    return Colors.blue;
  }

  String _getStatusLabel(String status) {
    if (status == "completed") return "Concluído";
    if (status == "pending") return "Pendente";
    return "Em análise";
  }
}
