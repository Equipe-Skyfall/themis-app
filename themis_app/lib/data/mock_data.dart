// themis_app/lib/data/mock_data.dart
import 'package:themis_app/lib/models.dart';

final List<CaseHistory> mockCases = [
  CaseHistory(
    id: "1",
    title: "Silva vs. Banco X - Revisão Contratual",
    date: "2026-03-08",
    status: "completed",
    matchCount: 7,
  ),
  CaseHistory(
    id: "2",
    title: "Recurso de Amparo - João Pereira",
    date: "2026-03-05",
    status: "completed",
    matchCount: 4,
  ),
  CaseHistory(
    id: "3",
    title: "Ação Indenizatória - Maria Santos",
    date: "2026-03-01",
    status: "completed",
    matchCount: 12,
  ),
  CaseHistory(
    id: "4",
    title: "Mandado de Segurança - Tech Corp",
    date: "2026-02-28",
    status: "pending",
    matchCount: 0,
  ),
  CaseHistory(
    id: "5",
    title: "Recurso Especial - Construtora Alpha",
    date: "2026-02-20",
    status: "completed",
    matchCount: 9,
  ),
];

final List<Precedent> mockPrecedents = [
  Precedent(
    id: "1",
    title: "Recurso Extraordinário 882.201",
    tribunal: "STF",
    similarity: 94,
    status: "applicable",
    legalStatus: "Trânsito em Julgado",
    theme:
        "Limitação de juros remuneratórios em contratos bancários de financiamento imobiliário",
    thesis:
        "A cláusula de reajuste em contratos bancários deve observar os índices oficiais, sendo vedada a aplicação de taxas superiores àquelas estabelecidas pelo Conselho Monetário Nacional.",
    summary:
        "RE que firmou entendimento sobre a limitação de juros em contratos bancários de financiamento imobiliário.",
    whyApplies:
        "O caso em análise trata exatamente da mesma matéria: revisão de cláusula contratual bancária com juros abusivos. A tese firmada neste RE pode ser diretamente aplicada como fundamento principal da ação.",
  ),
  // Adicionado apenas 1 completo para não prolongar, adicionei o resto condensado
  Precedent(
    id: "2",
    title: "REsp 1.578.553/SP",
    tribunal: "STJ",
    similarity: 87,
    status: "applicable",
    legalStatus: "Vigente",
    theme: "Revisão de taxas de juros abusivos em contratos bancários",
    thesis:
        "É possível a revisão das taxas de juros em contratos bancários quando demonstrada a abusividade, cabendo ao julgador fixar a taxa adequada.",
    summary:
        "Recurso Especial que consolidou jurisprudência sobre revisão de juros bancários abusivos.",
    whyApplies:
        "Reforça o argumento central do caso, estabelecendo que a simples demonstração de abusividade já é suficiente para a revisão contratual.",
  ),
];
