import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../hooks/use_upload_petition_controller.dart';
import 'package:themis_app/lib/models.dart';
import 'package:themis_app/lib/profile_mode.dart';
import '../ui/app_bar.dart';

class UploadScreen extends HookWidget {
  final String? token;
  final VoidCallback? onBack;
  final ProfileMode profileMode;
  final void Function(
    String caseTitle,
    List<Precedent> precedents,
    String? summary,
    Map<String, dynamic>? analysisData,
  )? onAnalysisReady;

  const UploadScreen({
    super.key,
    required this.token,
    required this.profileMode,
    this.onBack,
    this.onAnalysisReady,
  });

  static const Color _primary = Color(0xFF1D2A7A);

  @override
  Widget build(BuildContext context) {
    final upload = useUploadPetitionController(token: token);
    final isLoadingVisible = useState(false);
    final loadingStep = useState(0);
    final resultsLimit = useState(10);
    final limitController = useTextEditingController(text: '10');
    final limitError = useState<String?>(null);

    // Aba de texto (só para Advogado)
    final textController = useTextEditingController();
    final activeTab = useState(0); // 0 = PDF, 1 = Texto

    final bool isJudge = profileMode == ProfileMode.judge;
    final bool hasFile = upload.selectedFile != null;

    // ── Loading step timer ──
    useEffect(() {
      if (!isLoadingVisible.value) {
        loadingStep.value = 0;
        return null;
      }
      final timer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
        if (loadingStep.value < _loadingTexts.length - 1) {
          loadingStep.value++;
        }
      });
      return timer.cancel;
    }, [isLoadingVisible.value]);

    // ── Submit ──
    Future<void> onSubmit() async {
      final parsedLimit = int.tryParse(limitController.text.trim());
      if (parsedLimit == null || parsedLimit <= 0) {
        limitError.value = 'Digite um número maior que 0.';
        return;
      }

      if (parsedLimit > 20) {
        limitError.value = 'Use no máximo 20 precedentes.';
        return;
      }

      resultsLimit.value = parsedLimit;
      limitError.value = null;

      // Modo Advogado + aba Texto
      if (!isJudge && activeTab.value == 1) {
        if (textController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cole o texto da petição antes de continuar.'),
            ),
          );
          return;
        }
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Em breve 🚀'),
              content: const Text(
                'A análise via texto colado estará disponível em breve. '
                'Por enquanto, utilize o upload de PDF.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (!hasFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um PDF primeiro.')),
        );
        return;
      }

      isLoadingVisible.value = true;

      // Chama a rota certa dependendo do perfil
      final result = isJudge
          ? await upload.generateCaseAnalysis(limit: parsedLimit)
          : await upload.generateAnalysis(limit: parsedLimit);

      isLoadingVisible.value = false;

      if (result == null) {
        if (upload.errorMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(upload.errorMessage!)),
          );
        }
        return;
      }

      if (result.precedents.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum precedente encontrado.')),
          );
        }
        return;
      }

      final fileName = upload.selectedFile?.name ?? 'Arquivo';
      final limited = result.precedents.take(parsedLimit).toList();
      onAnalysisReady?.call(
        isJudge ? 'Processo - $fileName' : 'Petição - $fileName',
        limited,
        result.summary,
        result.analysisData,
      );
    }

    // ── Loading screen ──
    if (isLoadingVisible.value) {
      return _LoadingScreen(step: loadingStep.value, isJudge: isJudge);
    }

    // ── Títulos por perfil ──
    final title = isJudge ? 'Nova Análise de Processo' : 'Nova Análise de Petição';
    final subtitle = isJudge
        ? 'Envie o PDF do processo para análise jurídica'
        : 'Upload de PDF ou cole o texto da petição';
    final buttonLabel =
        isJudge ? 'Analisar Processo' : 'Gerar Análise Jurídica';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'THEMIS',
        showSettings: false,
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2C))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

            // ── Tabs (só Advogado) ──
            if (!isJudge) ...[
              _TabBar(
                activeIndex: activeTab.value,
                onTabChanged: (i) => activeTab.value = i,
              ),
              const SizedBox(height: 16),
            ],

            // ── Filtro de precedentes ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantidade de precedentes',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E1E2C),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Escolha um valor rápido ou digite manualmente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 20].map((option) {
                      final selected = resultsLimit.value == option;
                      return ChoiceChip(
                        label: Text(
                          '$option',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) {
                          resultsLimit.value = option;
                          limitController.text = option.toString();
                          limitError.value = null;
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: const Color(0xFF1E1E2C),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Quantidade de precedentes',
                      hintText: 'Ex.: 15',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E1E2C)),
                      ),
                      errorText: limitError.value,
                    ),
                    onChanged: (_) {
                      if (limitError.value != null) {
                        limitError.value = null;
                      }
                    },
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0 && parsed <= 20) {
                        resultsLimit.value = parsed;
                        limitError.value = null;
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Conteúdo da aba ──
            if (!isJudge && activeTab.value == 1)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Cole aqui o texto completo da petição...',
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              )
            else
              // Upload PDF
              GestureDetector(
                onTap: upload.isSubmitting ? null : upload.pickPDF,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: hasFile ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasFile ? _primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasFile ? Icons.picture_as_pdf : Icons.upload_file,
                        size: 40,
                        color: hasFile ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        upload.selectedFile?.name ??
                            'Toque para selecionar um PDF',
                        style: TextStyle(
                          color: hasFile ? Colors.white : Colors.grey,
                          fontWeight: hasFile
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Botão Enviar ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: upload.isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: upload.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(buttonLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TabBar (Advogado: PDF | Texto) ──────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTabChanged;

  const _TabBar({required this.activeIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabCard(
            label: 'Upload PDF',
            subtitle: 'Enviar petição em PDF',
            icon: Icons.picture_as_pdf_outlined,
            isActive: activeIndex == 0,
            onTap: () => onTabChanged(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TabCard(
            label: 'Colar Texto',
            subtitle: 'Digitar ou colar petição',
            icon: Icons.content_paste_rounded,
            isActive: activeIndex == 1,
            onTap: () => onTabChanged(1),
          ),
        ),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF1D2A7A) : Colors.grey.shade200,
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF1D2A7A).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1D2A7A).withOpacity(0.08)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isActive ? const Color(0xFF1D2A7A) : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF1E1E2C) : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading screen ───────────────────────────────────────────────────────────

const _loadingTexts = <String>[
  'Extraindo fundamentos jurídicos...',
  'Consultando base Pangea...',
  'Identificando teses aplicáveis...',
  'Calculando probabilidade de êxito...',
  'Organizando precedentes por relevância...',
];

const _loadingIcons = <IconData>[
  Icons.picture_as_pdf,
  Icons.find_in_page,
  Icons.gavel,
  Icons.task_alt,
];

class _LoadingScreen extends StatelessWidget {
  final int step;
  final bool isJudge;

  const _LoadingScreen({required this.step, required this.isJudge});

  @override
  Widget build(BuildContext context) {
    final currentStep = step % _loadingTexts.length;
    final currentIconStep = step % _loadingIcons.length;
    final progress = (currentStep + 1) / _loadingTexts.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            color: Color(0xFF1D2A7A),
                          ),
                        ),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1D2A7A),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                  scale: animation, child: child),
                            ),
                            child: Icon(
                              _loadingIcons[currentIconStep],
                              key: ValueKey<int>(currentIconStep),
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    isJudge ? 'Analisando processo...' : 'Analisando petição...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D2A7A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Barra de progresso
                  Container(
                    width: 220,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7ECF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D2A7A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      _loadingTexts[currentStep],
                      key: ValueKey<int>(currentStep),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
