import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../hooks/use_upload_petition_controller.dart';
import '../../lib/models.dart';
import '../ui/app_bar.dart';

class UploadScreen extends HookWidget {
  final String? token;
  final VoidCallback? onBack;
  final void Function(String caseTitle, List<Precedent> precedents)?
  onAnalysisReady;

  const UploadScreen({
    super.key,
    required this.token,
    this.onBack,
    this.onAnalysisReady,
  });

  final Color activeColor = const Color(0xFF1E1E2C);

  @override
  Widget build(BuildContext context) {
    final upload = useUploadPetitionController(token: token);
    final hasFile = upload.selectedFile != null;
    final isLoadingScreenVisible = useState(false);
    final loadingStep = useState(0);

    useEffect(() {
      if (!isLoadingScreenVisible.value) {
        loadingStep.value = 0;
        return null;
      }

      final timer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
        if (loadingStep.value < _loadingTexts.length - 1) {
          loadingStep.value = loadingStep.value + 1;
        }
      });

      return timer.cancel;
    }, [isLoadingScreenVisible.value]);

    Future<void> onGeneratePressed() async {
      isLoadingScreenVisible.value = true;

      final precedents = await upload.generateAnalysis();
      isLoadingScreenVisible.value = false;

      if (precedents == null) {
        if (upload.errorMessage != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(upload.errorMessage!)));
        }
        return;
      }

      if (precedents.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum precedente encontrado.')),
          );
        }
        return;
      }

      final fileName = upload.selectedFile?.name ?? 'Peticao';
      onAnalysisReady?.call('Analise - $fileName', precedents);
    }

    if (isLoadingScreenVisible.value) {
      return _AnalysisLoadingScreen(step: loadingStep.value);
    }

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
            const Text(
              'Nova Análise',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upload de arquivos',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: upload.pickPDF,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: hasFile ? activeColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFile ? activeColor : Colors.grey.shade300,
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
                          'Toque para selecionar um arquivo PDF',
                      style: TextStyle(
                        color: hasFile ? Colors.white : Colors.grey,
                        fontWeight: hasFile
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
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
                onPressed: upload.isSubmitting ? null : onGeneratePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasFile ? activeColor : Colors.grey.shade300,
                  foregroundColor: hasFile ? Colors.white : Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Gerar Analise Juridica'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
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

const _loadingTexts = <String>[
  'Extraindo fundamentos juridicos...',
  'Consultando base Pangea...',
  'Identificando teses aplicaveis...',
  'Calculando probabilidade de exito...',
  'Organizando precedentes por relevancia...',
];

const _loadingIcons = <IconData>[
  Icons.picture_as_pdf,
  Icons.find_in_page,
  Icons.gavel,
  Icons.task_alt,
];

class _AnalysisLoadingScreen extends StatelessWidget {
  final int step;

  const _AnalysisLoadingScreen({required this.step});

  @override
  Widget build(BuildContext context) {
    final currentStep = step % _loadingTexts.length;
    final currentIconStep = _loadingIcons.isEmpty
        ? 0
        : (step % _loadingIcons.length);
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
                            color: Color(0xFF1E5EFF),
                          ),
                        ),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E5EFF),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              );
                            },
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
                  const SizedBox(height: 24),
                  const Text(
                    'Analisando peticao',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 220,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7ECF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E5EFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      _loadingTexts[currentStep],
                      key: ValueKey<int>(currentStep),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
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
