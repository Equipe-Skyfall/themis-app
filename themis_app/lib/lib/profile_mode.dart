// themis_app/lib/lib/profile_mode.dart

/// Perfil ativo no app — controla qual aba da navbar está selecionada
/// e qual fluxo de análise o FAB "+" aciona.
enum ProfileMode {
  /// Frente Advogado — petições e ações
  lawyer,

  /// Frente Juiz — processos numerados
  judge,
}
