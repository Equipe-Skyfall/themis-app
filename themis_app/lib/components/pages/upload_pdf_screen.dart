import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../data/petition/petition_api_service.dart';
import '../../data/petition/case_analysis_api_service.dart';
import 'package:themis_app/lib/models.dart';
import 'package:themis_app/lib/profile_mode.dart';
import '../ui/app_bar.dart';
import '../../hooks/use_upload_petition_controller.dart' show toPrecedent;

const _orgaoOptions = <String>[
  'STF',
  'STJ',
  'TST',
  'TRF',
  'TRT',
  'TJSP',
  'TJRJ',
  'TJMG',
  'TJRS',
  'TJPR',
  'TJSC',
];

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

  /// Chamado quando o PDF é enviado ao servidor e o job_id é recebido.
  /// O polling continua em background no AppController.
  final void Function(String jobId, String fileName, int candidates)?
      onAnalysisJobStarted;

  /// Chamado quando a petição é gerada (Frente 1 — Advogado).
  final void Function(
    String petitionText,
    String caseDescription,
    List<Precedent> precedents,
    bool weakPrecedents,
  )? onPetitionGenerated;

  const UploadScreen({
    super.key,
    required this.token,
    required this.profileMode,
    this.onBack,
    this.onAnalysisReady,
    this.onAnalysisJobStarted,
    this.onPetitionGenerated,
  });

  @override
  Widget build(BuildContext context) {
    final isJudge = profileMode == ProfileMode.judge;

    // ── Estado compartilhado ──
    final isLoadingVisible = useState(false);
    final loadingStep = useState(0);

    // ── Estado do Juiz (upload PDF) ──
    final judgeService = useMemoized(() => CaseAnalysisApiService());
    final selectedFile = useState<PlatformFile?>(null);
    final resultsLimit = useState(10);
    final limitController = useTextEditingController(text: '10');
    final limitError = useState<String?>(null);

    // ── Estado do Advogado (Nova Petição) ──
    final petitionService = useMemoized(() => PetitionApiService());
    final textController = useTextEditingController();
    final selectedOrgao = useState<String?>(null);
    final attachedFile = useState<PlatformFile?>(null);

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

    // ── Selecionar PDF para Juiz ──
    Future<void> pickJudgePDF() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        selectedFile.value = result.files.first;
      }
    }

    // ── Anexar PDF para Advogado ──
    Future<void> attachLawyerPDF() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        attachedFile.value = result.files.first;
      }
    }

    // ── Submit Juiz ──
    Future<void> submitJudge() async {
      final parsedLimit = int.tryParse(limitController.text.trim());
      if (parsedLimit == null || parsedLimit <= 0) {
        limitError.value = 'Digite um número maior que 0.';
        return;
      }
      if (parsedLimit > 20) {
        limitError.value = 'Use no máximo 20 precedentes.';
        return;
      }
      limitError.value = null;
      resultsLimit.value = parsedLimit;

      final file = selectedFile.value;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um PDF primeiro.')),
        );
        return;
      }
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler o PDF.')),
        );
        return;
      }

      // Mostra loading breve enquanto o arquivo é enviado ao servidor
      isLoadingVisible.value = true;

      try {
        final jobId = await judgeService.submitCaseForAnalysis(
          token ?? '',
          file.name,
          bytes,
        );

        isLoadingVisible.value = false;

        // Entrega o job_id ao AppController que faz o polling em background
        onAnalysisJobStarted?.call(jobId, file.name, parsedLimit);
      } on CaseAnalysisApiException catch (e) {
        isLoadingVisible.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } catch (_) {
        isLoadingVisible.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao enviar processo. Tente novamente.')),
          );
        }
      }
    }

    // ── Submit Advogado ──
    Future<void> submitLawyer() async {
      final description = textController.text.trim();
      if (description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descreva o caso antes de continuar.')),
        );
        return;
      }

      isLoadingVisible.value = true;

      try {
        final file = attachedFile.value;
        final Uint8List? pdfBytes = file?.bytes;
        final String? pdfFileName = file?.name;

        final result = await petitionService.generatePetitionWithPolling(
          token: token ?? '',
          caseDescription: description,
          orgaoFilter: selectedOrgao.value,
          pdfBytes: pdfBytes,
          pdfFileName: pdfFileName,
        );

        isLoadingVisible.value = false;

        final petitionText = result['petition_text'] as String? ?? '';
        if (petitionText.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível gerar a petição. Tente novamente.'),
              ),
            );
          }
          return;
        }

        final rawList =
            (result['precedent_results'] as List<Map<String, dynamic>>?) ?? [];
        final precedents = rawList.map(toPrecedent).toList();
        final weakPrecedents = result['weak_precedents'] as bool? ?? false;

        onPetitionGenerated?.call(petitionText, description, precedents, weakPrecedents);
      } on PetitionApiException catch (e) {
        isLoadingVisible.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } catch (_) {
        isLoadingVisible.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao gerar petição. Tente novamente.')),
          );
        }
      }
    }

    // ── Loading screen ──
    if (isLoadingVisible.value) {
      return _LoadingScreen(step: loadingStep.value, isJudge: isJudge);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'THEMIS',
        showSettings: false,
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      body: isJudge
          ? _JudgeForm(
              selectedFile: selectedFile.value,
              resultsLimit: resultsLimit.value,
              limitController: limitController,
              limitError: limitError.value,
              onPickFile: pickJudgePDF,
              onSubmit: submitJudge,
              onLimitChanged: (val) {
                resultsLimit.value = val;
                limitController.text = val.toString();
                limitError.value = null;
              },
              onLimitErrorClear: () => limitError.value = null,
            )
          : _LawyerForm(
              textController: textController,
              selectedOrgao: selectedOrgao.value,
              attachedFile: attachedFile.value,
              onOrgaoChanged: (v) => selectedOrgao.value = v,
              onAttachFile: attachLawyerPDF,
              onRemoveFile: () => attachedFile.value = null,
              onSubmit: submitLawyer,
            ),
    );
  }
}

// ─── Formulário do Juiz (upload PDF + filtro de precedentes) ──────────────────

class _JudgeForm extends StatelessWidget {
  final PlatformFile? selectedFile;
  final int resultsLimit;
  final TextEditingController limitController;
  final String? limitError;
  final VoidCallback onPickFile;
  final Future<void> Function() onSubmit;
  final void Function(int) onLimitChanged;
  final VoidCallback onLimitErrorClear;

  const _JudgeForm({
    required this.selectedFile,
    required this.resultsLimit,
    required this.limitController,
    required this.limitError,
    required this.onPickFile,
    required this.onSubmit,
    required this.onLimitChanged,
    required this.onLimitErrorClear,
  });

  static const Color _primary = Color(0xFF1D2A7A);

  @override
  Widget build(BuildContext context) {
    final hasFile = selectedFile != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nova Análise de Processo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Envie o PDF do processo para análise jurídica',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Filtro de precedentes
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
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
                    final selected = resultsLimit == option;
                    return ChoiceChip(
                      label: Text(
                        '$option',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => onLimitChanged(option),
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: const Color(0xFF1E1E2C),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Quantidade de precedentes',
                    hintText: 'Ex.: 15',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E1E2C)),
                    ),
                    errorText: limitError,
                  ),
                  onChanged: (_) => onLimitErrorClear(),
                  onSubmitted: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null && parsed > 0 && parsed <= 20) {
                      onLimitChanged(parsed);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Upload PDF
          GestureDetector(
            onTap: onPickFile,
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
                    selectedFile?.name ?? 'Toque para selecionar um PDF',
                    style: TextStyle(
                      color: hasFile ? Colors.white : Colors.grey,
                      fontWeight:
                          hasFile ? FontWeight.w500 : FontWeight.normal,
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

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Analisar Processo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formulário do Advogado (Nova Petição: texto + PDF opcional + filtro órgão) ─

class _LawyerForm extends StatelessWidget {
  final TextEditingController textController;
  final String? selectedOrgao;
  final PlatformFile? attachedFile;
  final void Function(String?) onOrgaoChanged;
  final VoidCallback onAttachFile;
  final VoidCallback onRemoveFile;
  final Future<void> Function() onSubmit;

  const _LawyerForm({
    required this.textController,
    required this.selectedOrgao,
    required this.attachedFile,
    required this.onOrgaoChanged,
    required this.onAttachFile,
    required this.onRemoveFile,
    required this.onSubmit,
  });

  static const Color _primary = Color(0xFF1D2A7A);

  @override
  Widget build(BuildContext context) {
    final hasFile = attachedFile != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nova Petição',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Descreva o caso e gere uma petição completa com precedentes',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Descrição do caso
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(minHeight: 140),
            child: TextField(
              controller: textController,
              maxLines: null,
              minLines: 6,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText:
                    'Descreva o caso jurídico em detalhes...\n\nEx: Meu cliente foi demitido sem justa causa após 5 anos de empresa. Não recebeu aviso prévio e as verbas rescisórias foram pagas com atraso...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),

          // Label + nota sobre o PDF
          const Text(
            'Documento anexo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E2C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Opcional — porém, para fornecer contexto adicional ao caso e gerar a minuta (contrato, correspondência, etc.), você pode anexar um PDF.',
            style: TextStyle(fontSize: 12, color: Color(0xFF74839A), height: 1.4),
          ),
          const SizedBox(height: 8),

          // Anexar PDF (opcional)
          GestureDetector(
            onTap: hasFile ? null : onAttachFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: hasFile
                    ? _primary.withOpacity(0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFile ? _primary : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFile ? Icons.picture_as_pdf : Icons.attach_file_rounded,
                    size: 22,
                    color: hasFile ? _primary : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasFile
                          ? attachedFile!.name
                          : 'Anexar PDF (opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasFile ? _primary : Colors.grey.shade600,
                        fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasFile)
                    GestureDetector(
                      onTap: onRemoveFile,
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade500),
                    )
                  else
                    Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filtro por órgão
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedOrgao,
                isExpanded: true,
                hint: const Text(
                  'Filtrar por órgão (opcional)',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos os órgãos',
                        style: TextStyle(fontSize: 13)),
                  ),
                  ..._orgaoOptions.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o,
                      child: Text(o, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
                onChanged: onOrgaoChanged,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gerar Petição',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
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
      canPop: true,
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
                    isJudge ? 'Analisando processo...' : 'Gerando petição...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D2A7A),
                    ),
                  ),
                  const SizedBox(height: 20),
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
