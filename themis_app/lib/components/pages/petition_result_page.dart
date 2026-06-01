import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'dart:io';

import '../../data/petition/petition_api_service.dart';
import 'package:themis_app/lib/models.dart';
import '../ui/app_bar.dart';
import '../ui/precedent_sheet.dart';
import '../../services/pdf_export_service.dart';

class PetitionResultPage extends StatefulWidget {
  final String initialPetitionText;
  final String caseDescription;
  final List<Precedent> initialPrecedents;
  final bool initialWeakPrecedents;
  final String? token;
  final VoidCallback onBack;

  const PetitionResultPage({
    super.key,
    required this.initialPetitionText,
    required this.caseDescription,
    required this.initialPrecedents,
    required this.initialWeakPrecedents,
    required this.token,
    required this.onBack,
  });

  @override
  State<PetitionResultPage> createState() => _PetitionResultPageState();
}

class _PetitionResultPageState extends State<PetitionResultPage> {
  static const _primary = Color(0xFF1D2A7A);

  late String _petitionText;
  late List<Precedent> _precedents;
  late bool _weakPrecedents;
  final Set<String> _selectedApplicability = {};

  static const List<_FilterOption> _filterOptions = [
    _FilterOption(status: 'applicable', label: 'Aplicável', color: Color(0xFF4CAF50)),
    _FilterOption(status: 'possibly_applicable', label: 'Possivelmente Aplicável', color: Color(0xFFF9A825)),
    _FilterOption(status: 'not_applicable', label: 'Não Aplicável', color: Color(0xFFD94841)),
  ];

  @override
  void initState() {
    super.initState();
    _petitionText = widget.initialPetitionText;
    _precedents = widget.initialPrecedents;
    _weakPrecedents = widget.initialWeakPrecedents;
  }

  List<Precedent> get _visiblePrecedents {
    if (_selectedApplicability.isEmpty) return _precedents;
    return _precedents
        .where((p) => _selectedApplicability.contains(_normalizeStatus(p.status)))
        .toList();
  }

  String _normalizeStatus(String status) =>
      status == 'preliminary' ? 'possibly_applicable' : status;

  void _toggleFilter(String status) => setState(() {
        if (_selectedApplicability.contains(status)) {
          _selectedApplicability.remove(status);
        } else {
          _selectedApplicability.add(status);
        }
      });

  void _clearFilters() => setState(() => _selectedApplicability.clear());

  bool _hasOnlyWeakPrecedents() =>
      _precedents.isNotEmpty &&
      !_precedents.any((p) => _normalizeStatus(p.status) == 'applicable');

  void _openExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSelectionSheet(
        petitionText: _petitionText,
        caseDescription: widget.caseDescription,
        precedents: _precedents,
      ),
    );
  }

  void _openPetitionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PetitionSheet(
        petitionText: _petitionText,
        caseDescription: widget.caseDescription,
        token: widget.token,
        onRegenerated: (newText, newPrecedents, newWeak) {
          setState(() {
            _petitionText = newText;
            _precedents = newPrecedents;
            _weakPrecedents = newWeak;
            _selectedApplicability.clear();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePrecedents;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Minuta Inicial',
        onBack: widget.onBack,
        showSettings: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──
            const Text(
              'Minuta Inicial',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
              ),
            ),
            Text(
              'Minuta inicial gerada com IA a partir do seu caso',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),

            // ── Alerta precedentes fracos ──
            if (_weakPrecedents || (_hasOnlyWeakPrecedents() && _selectedApplicability.isEmpty))
              _buildWeakPrecedentsAlert(),

            // ── Card: Minuta Inicial (abre bottom sheet) ──
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _openPetitionSheet,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.article_rounded,
                          color: _primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minuta Inicial',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1E2C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Visualizar, editar e regenerar petição',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF74839A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF74839A)),
                    ],
                  ),
                ),
              ),
            ),

            // ── Descrição do caso (barra lateral azul) ──
            if (widget.caseDescription.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DESCRIÇÃO DO CASO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.caseDescription,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3A3A4A),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Título: Precedentes ──
            const Text(
              'Precedentes Encontrados',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 18),

            // ── Filtro de aplicabilidade ──
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filtro de aplicabilidade',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1E2C),
                          ),
                        ),
                      ),
                      if (_selectedApplicability.isNotEmpty)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedApplicability.isEmpty
                        ? 'Nenhum filtro ativo. Todos os precedentes estão visíveis.'
                        : 'Filtro(s) ativo(s): ${_selectedApplicability.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: _filterOptions.map((opt) {
                      final selected = _selectedApplicability.contains(opt.status);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleFilter(opt.status),
                              borderRadius: BorderRadius.circular(24),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? opt.color.withValues(alpha: 0.14)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: selected ? opt.color : Colors.grey[300]!,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    opt.label,
                                    style: TextStyle(
                                      color: selected ? opt.color : const Color(0xFF334155),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _precedents.isEmpty ? null : _openExportSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Exportar para PDF',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cards de precedentes ──
            ...visible.map((p) => _PrecedentCard(
                  precedent: p,
                  onTap: () => showPrecedentSheet(context, p),
                )),

            if (visible.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  _selectedApplicability.isEmpty
                      ? 'Nenhum precedente encontrado.'
                      : 'Nenhum precedente para o filtro selecionado.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // ── Botão Regenerar fixo no fundo ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openPetitionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Ver / Regenerar Petição',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeakPrecedentsAlert() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFF9A825), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atenção: Sem precedentes fortes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nenhum precedente com alta relevância foi encontrado. '
                  'A petição pode ter fundamentos menos sólidos. '
                  'Recomendamos revisar com cautela.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter option model ──────────────────────────────────────────────────────

class _FilterOption {
  final String status;
  final String label;
  final Color color;
  const _FilterOption({required this.status, required this.label, required this.color});
}

// ─── Precedent Card (mesmo estilo do ResultsPage) ─────────────────────────────

class _PrecedentCard extends StatelessWidget {
  final Precedent precedent;
  final VoidCallback onTap;

  const _PrecedentCard({required this.precedent, required this.onTap});

  static const _similarityColor = Color(0xFF1D2A7A);

  Color _statusColor(String s) {
    switch (s) {
      case 'applicable':
        return const Color(0xFF4CAF50);
      case 'not_applicable':
        return const Color(0xFFD94841);
      default:
        return const Color(0xFFF9A825);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'applicable':
        return 'Aplicável';
      case 'not_applicable':
        return 'Não Aplicável';
      default:
        return 'Possivelmente Aplicável';
    }
  }

  String _normalize(String input) => input
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
      .replaceAll('é', 'e').replaceAll('ê', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
      .replaceAll('ú', 'u').replaceAll('ç', 'c');

  String _buildMeta() {
    final normalizedStatus = _normalize(_statusLabel(precedent.status));
    final legal = precedent.legalStatus.trim();
    if (legal.isEmpty || _normalize(legal) == normalizedStatus) {
      return precedent.tribunal;
    }
    return '${precedent.tribunal} · $legal';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(precedent.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        precedent.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E2C),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildMeta(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF74839A),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${precedent.similarity.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _similarityColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      'similaridade',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              precedent.theme,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5F728D),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(precedent.status),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet: Visualizar / Editar / Regenerar Petição ───────────────────

class _PetitionSheet extends StatefulWidget {
  final String petitionText;
  final String caseDescription;
  final String? token;
  final void Function(String, List<Precedent>, bool) onRegenerated;

  const _PetitionSheet({
    required this.petitionText,
    required this.caseDescription,
    required this.token,
    required this.onRegenerated,
  });

  @override
  State<_PetitionSheet> createState() => _PetitionSheetState();
}

class _PetitionSheetState extends State<_PetitionSheet> {
  static const _primary = Color(0xFF1D2A7A);

  late final TextEditingController _petitionCtrl;
  late final TextEditingController _instructionsCtrl;
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isExporting = false;
  String _loadingText = 'Regenerando petição...';
  int _loadingStep = 0;
  Timer? _loadingTimer;

  static const _loadingTexts = [
    'Analisando instruções...',
    'Consultando precedentes relevantes...',
    'Reestruturando fundamentos jurídicos...',
    'Redigindo nova petição...',
    'Finalizando...',
  ];

  @override
  void initState() {
    super.initState();
    _petitionCtrl = TextEditingController(text: widget.petitionText);
    _instructionsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _petitionCtrl.dispose();
    _instructionsCtrl.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _startLoadingAnimation() {
    _loadingStep = 0;
    _loadingText = _loadingTexts[0];
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) return;
      setState(() {
        _loadingStep = (_loadingStep + 1) % _loadingTexts.length;
        _loadingText = _loadingTexts[_loadingStep];
      });
    });
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);
    try {
      final path = await PDFExportService.exportPetitionToPdf(
        petitionText: _petitionCtrl.text,
        caseDescription: widget.caseDescription,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvo: ${path.split(Platform.pathSeparator).last}'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: const Color(0xFFD94841),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _copyPetition() async {
    await Clipboard.setData(ClipboardData(text: _petitionCtrl.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Petição copiada para a área de transferência.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerate() async {
    final tok = widget.token;
    if (tok == null || tok.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _startLoadingAnimation();

    try {
      final service = PetitionApiService();
      final result = await service.regeneratePetitionWithPolling(
        token: tok,
        caseDescription: widget.caseDescription,
        petitionText: _petitionCtrl.text,
        instructions: _instructionsCtrl.text.trim().isNotEmpty
            ? _instructionsCtrl.text.trim()
            : null,
        onStatusUpdate: (msg) {
          if (mounted) setState(() => _loadingText = msg);
        },
      );

      _loadingTimer?.cancel();

      final newText = result['petition_text'] as String? ?? '';
      if (newText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível regenerar a petição.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final rawList = (result['precedent_results'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      final newPrecedents = rawList.map(_toPrecedent).toList();
      final newWeak = result['weak_precedents'] as bool? ?? false;

      if (mounted) Navigator.of(context).pop();
      widget.onRegenerated(newText, newPrecedents, newWeak);
    } on PetitionApiException catch (e) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao regenerar petição. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _isLoading ? _buildLoading() : _buildContent(scrollController),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(strokeWidth: 4, color: _primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Regenerando petição...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                _loadingText,
                key: ValueKey(_loadingText),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minuta Inicial',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Edite o texto ou adicione instruções para regenerar',
                      style: TextStyle(fontSize: 12, color: Color(0xFF74839A)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isEditMode ? 'Visualizar' : 'Editar',
                icon: Icon(
                  _isEditMode ? Icons.visibility_outlined : Icons.edit_outlined,
                  color: const Color(0xFF74839A),
                ),
                onPressed: () => setState(() => _isEditMode = !_isEditMode),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy_outlined, color: Color(0xFF74839A)),
                onPressed: _copyPetition,
              ),
              _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1D2A7A),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Baixar PDF',
                      icon: const Icon(Icons.download_rounded, color: Color(0xFF74839A)),
                      onPressed: _exportToPdf,
                    ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF74839A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Petição (preview ou edit)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            const Text(
                              'TEXTO DA PETIÇÃO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _isEditMode ? 'Editando' : 'Toque ✏️ para editar',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (_isEditMode)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 280),
                          child: IntrinsicHeight(
                            child: TextField(
                              controller: _petitionCtrl,
                              maxLines: null,
                              expands: false,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(fontSize: 13, height: 1.6),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(16),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: MarkdownBody(
                            data: _petitionCtrl.text,
                            styleSheet: MarkdownStyleSheet(
                              h1: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C)),
                              h2: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: _primary),
                              h3: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2C)),
                              p: const TextStyle(
                                  fontSize: 13, color: Color(0xFF3A3A4A), height: 1.6),
                              strong: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Instruções
                const Text(
                  'Instruções para regenerar',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E1E2C)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Descreva o que deve ser alterado ou melhorado.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _instructionsCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Ex: Adicione mais fundamentos sobre dano moral, enfatize o pedido de tutela antecipada...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _regenerate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(
                      'Regenerar com novos precedentes',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Precedent _toPrecedent(Map<String, dynamic> item) {
  final relevance = _normalizeLabel((item['relevance_label'] ?? '').toString());
  final status = switch (relevance) {
    'aplicavel' => 'applicable',
    'possivelmente aplicavel' => 'possibly_applicable',
    'nao aplicavel' => 'not_applicable',
    _ => 'possibly_applicable',
  };

  final rawId = (item['id'] ?? '').toString().trim();
  final explanation = (item['explanation'] ?? '').toString().trim();
  final enunciado = _pickFirstText(item, ['textoEmenta', 'textoDecisao']) ?? explanation;
  final tese = (item['tese'] ?? '').toString().trim();
  final situacao = (item['situacao'] ?? '').toString().trim();

  return Precedent(
    id: rawId,
    title: rawId.isNotEmpty ? rawId : 'ID não informado',
    tribunal: (item['orgao'] ?? 'Tribunal não informado').toString(),
    similarity: _toDouble(item['similarity_score']),
    status: status,
    legalStatus: (item['relevance_label'] ?? '').toString(),
    situacao: situacao,
    theme: (item['questao'] ?? 'Tema não informado').toString(),
    thesis: tese.isNotEmpty ? tese : explanation,
    summary: enunciado.isNotEmpty ? enunciado : 'Não informado',
    whyApplies: explanation.isNotEmpty ? explanation : 'Não informado',
  );
}

String _normalizeLabel(String raw) => raw
    .toLowerCase().trim()
    .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
    .replaceAll('é', 'e').replaceAll('ê', 'e').replaceAll('í', 'i')
    .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
    .replaceAll('ú', 'u').replaceAll('ç', 'c');

double _toDouble(Object? value) {
  if (value is num) {
    var d = value.toDouble();
    if (d >= 0 && d <= 1) d = d * 100;
    return d.clamp(0, 100);
  }
  if (value is String) {
    var p = double.tryParse(value.replaceAll(',', '.'));
    if (p != null) {
      if (p >= 0 && p <= 1) p = p * 100;
      return p.clamp(0, 100);
    }
  }
  return 0;
}

String? _pickFirstText(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

// ─── Sheet: Seleção para Exportar PDF Completo ───────────────────────────────

class _ExportSelectionSheet extends StatefulWidget {
  final String petitionText;
  final String caseDescription;
  final List<Precedent> precedents;

  const _ExportSelectionSheet({
    required this.petitionText,
    required this.caseDescription,
    required this.precedents,
  });

  @override
  State<_ExportSelectionSheet> createState() => _ExportSelectionSheetState();
}

class _ExportSelectionSheetState extends State<_ExportSelectionSheet> {
  static const _primary = Color(0xFF1D2A7A);

  // Categorias de aplicabilidade disponíveis
  static final _categories = [
    _ApplicabilityCategory(
      status: 'applicable',
      label: 'Aplicável',
      color: const Color(0xFF4CAF50),
    ),
    _ApplicabilityCategory(
      status: 'possibly_applicable',
      label: 'Possivelmente Aplicável',
      color: const Color(0xFFF9A825),
    ),
    _ApplicabilityCategory(
      status: 'not_applicable',
      label: 'Não Aplicável',
      color: const Color(0xFFD94841),
    ),
  ];

  late bool _includePetition;
  late Set<String> _selectedStatuses;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _includePetition = widget.petitionText.trim().isNotEmpty;
    // Seleciona por padrão apenas as categorias que têm ao menos 1 precedente
    _selectedStatuses = _categories
        .where((c) => _countForStatus(c.status) > 0)
        .map((c) => c.status)
        .toSet();
  }

  int _countForStatus(String status) => widget.precedents
      .where((p) => _normalizeStatus(p.status) == status)
      .length;

  String _normalizeStatus(String s) =>
      s == 'preliminary' ? 'possibly_applicable' : s;

  List<Precedent> get _selectedPrecedents => widget.precedents
      .where((p) => _selectedStatuses.contains(_normalizeStatus(p.status)))
      .toList();

  Future<void> _export() async {
    final selected = _selectedPrecedents
        .map((p) => PrecedentExportData(precedent: p, includeTese: true))
        .toList();

    if (!_includePetition && selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione ao menos a petição ou uma categoria de precedentes.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final path = await PDFExportService.exportComprehensivePetitionPdf(
        caseDescription: widget.caseDescription,
        petitionText: _includePetition ? widget.petitionText : null,
        precedents: selected,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvo: ${path.split(Platform.pathSeparator).last}'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: const Color(0xFFD94841),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSelected = _selectedPrecedents.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exportar PDF Completo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E2C),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Selecione o que incluir no relatório',
                          style: TextStyle(fontSize: 12, color: Color(0xFF74839A)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF74839A)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Toggle: Petição ──
                    if (widget.petitionText.trim().isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: SwitchListTile(
                          value: _includePetition,
                          onChanged: (v) => setState(() => _includePetition = v),
                          activeTrackColor: _primary,
                          title: const Text(
                            'Incluir Minuta Inicial',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1E2C),
                            ),
                          ),
                          subtitle: const Text(
                            'Texto completo da petição em Markdown',
                            style: TextStyle(fontSize: 12, color: Color(0xFF74839A)),
                          ),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.article_rounded, color: _primary, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Filtro por aplicabilidade ──
                    const Text(
                      'Precedentes por aplicabilidade',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalSelected de ${widget.precedents.length} precedentes selecionados',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),

                    // Chips de categoria
                    ...(_categories.map((cat) {
                      final count = _countForStatus(cat.status);
                      final isOn = _selectedStatuses.contains(cat.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: count == 0
                              ? null
                              : () => setState(() {
                                    if (isOn) {
                                      _selectedStatuses.remove(cat.status);
                                    } else {
                                      _selectedStatuses.add(cat.status);
                                    }
                                  }),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: count == 0
                                  ? Colors.grey[50]
                                  : isOn
                                      ? cat.color.withValues(alpha: 0.08)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: count == 0
                                    ? Colors.grey[200]!
                                    : isOn
                                        ? cat.color
                                        : Colors.grey[300]!,
                                width: isOn ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? Colors.grey[300]
                                        : isOn
                                            ? cat.color
                                            : cat.color.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: count == 0
                                          ? Colors.grey[400]
                                          : isOn
                                              ? const Color(0xFF1E1E2C)
                                              : Colors.grey[500],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? Colors.grey[100]
                                        : isOn
                                            ? cat.color.withValues(alpha: 0.15)
                                            : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: count == 0
                                          ? Colors.grey[400]
                                          : isOn
                                              ? cat.color
                                              : Colors.grey[500],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isOn && count > 0
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: count == 0
                                      ? Colors.grey[300]
                                      : isOn
                                          ? cat.color
                                          : Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })),

                    const SizedBox(height: 28),

                    // ── Botão Exportar ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _export,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          _isExporting ? 'Exportando...' : 'Exportar para PDF',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ),
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

class _ApplicabilityCategory {
  final String status;
  final String label;
  final Color color;

  _ApplicabilityCategory({
    required this.status,
    required this.label,
    required this.color,
  });
}
