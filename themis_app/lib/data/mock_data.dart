// themis_app/lib/data/mock_data.dart
import 'package:themis_app/lib/models.dart';

// ─────────────────────────────────────────────
// Dashboard padrão — histórico geral
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Frente Advogado — petições e ações típicas
// ─────────────────────────────────────────────
final List<CaseHistory> mockLawyerCases = [
  CaseHistory(
    id: "l1",
    title: "Ação Trabalhista - Rescisão Indireta - Costa & Lima",
    date: "2026-05-10",
    status: "completed",
    matchCount: 11,
  ),
  CaseHistory(
    id: "l2",
    title: "Revisão Contratual - Juros Abusivos - Banco Nacional",
    date: "2026-05-07",
    status: "completed",
    matchCount: 8,
  ),
  CaseHistory(
    id: "l3",
    title: "Dano Moral - Protesto Indevido - Fernanda Alves",
    date: "2026-05-02",
    status: "completed",
    matchCount: 6,
  ),
  CaseHistory(
    id: "l4",
    title: "Ação de Alimentos - Guarda Compartilhada - Família Rocha",
    date: "2026-04-28",
    status: "completed",
    matchCount: 5,
  ),
  CaseHistory(
    id: "l5",
    title: "Usucapião Extraordinária - Imóvel Rural - Agro Sul",
    date: "2026-04-20",
    status: "completed",
    matchCount: 9,
  ),
  CaseHistory(
    id: "l6",
    title: "Mandado de Segurança - Licitação Pública - Prefeitura de SP",
    date: "2026-04-15",
    status: "pending",
    matchCount: 0,
  ),
  CaseHistory(
    id: "l7",
    title: "Execução Fiscal - IPTU - Oliveira Comércio ME",
    date: "2026-04-10",
    status: "completed",
    matchCount: 3,
  ),
];

// ─────────────────────────────────────────────
// Frente Juiz — processos numerados de tribunal
// ─────────────────────────────────────────────
final List<CaseHistory> mockJudgeCases = [
  CaseHistory(
    id: "j1",
    title: "Processo 0012345-67.2026.8.26.0100 — Sentença",
    date: "2026-05-15",
    status: "completed",
    matchCount: 14,
  ),
  CaseHistory(
    id: "j2",
    title: "Processo 0098712-34.2026.8.26.0001 — Despacho",
    date: "2026-05-12",
    status: "completed",
    matchCount: 7,
  ),
  CaseHistory(
    id: "j3",
    title: "Processo 0023456-89.2025.8.26.0100 — Decisão Interlocutória",
    date: "2026-05-08",
    status: "completed",
    matchCount: 5,
  ),
  CaseHistory(
    id: "j4",
    title: "Processo 0054321-12.2026.5.02.0001 — Sentença Trabalhista",
    date: "2026-05-05",
    status: "completed",
    matchCount: 10,
  ),
  CaseHistory(
    id: "j5",
    title: "Processo 0001122-33.2026.1.00.0000 — Acórdão STJ",
    date: "2026-04-30",
    status: "completed",
    matchCount: 18,
  ),
  CaseHistory(
    id: "j6",
    title: "Processo 0067890-45.2026.8.26.0200 — Análise Pendente",
    date: "2026-04-25",
    status: "pending",
    matchCount: 0,
  ),
  CaseHistory(
    id: "j7",
    title: "Processo 0034567-89.2025.8.26.0050 — Embargos de Declaração",
    date: "2026-04-18",
    status: "completed",
    matchCount: 4,
  ),
];

// ─────────────────────────────────────────────
// Precedentes mock (mantido)
// ─────────────────────────────────────────────
final List<Precedent> mockPrecedents = [
  Precedent(
    id: "1",
    title: "Recurso Extraordinário 882.201",
    tribunal: "STF",
    similarity: 94,
    status: "applicable",
    legalStatus: "Trânsito em Julgado",
    situacao: "transito_em_julgado",
    theme:
        "Limitação de juros remuneratórios em contratos bancários de financiamento imobiliário",
    thesis:
        "A cláusula de reajuste em contratos bancários deve observar os índices oficiais, sendo vedada a aplicação de taxas superiores àquelas estabelecidas pelo Conselho Monetário Nacional.",
    summary:
        "RE que firmou entendimento sobre a limitação de juros em contratos bancários de financiamento imobiliário.",
    whyApplies:
        "O caso em análise trata exatamente da mesma matéria: revisão de cláusula contratual bancária com juros abusivos. A tese firmada neste RE pode ser diretamente aplicada como fundamento principal da ação.",
  ),
  Precedent(
    id: "2",
    title: "REsp 1.578.553/SP",
    tribunal: "STJ",
    similarity: 87,
    status: "applicable",
    legalStatus: "Vigente",
    situacao: "vigente",
    theme: "Revisão de taxas de juros abusivos em contratos bancários",
    thesis:
        "É possível a revisão das taxas de juros em contratos bancários quando demonstrada a abusividade, cabendo ao julgador fixar a taxa adequada.",
    summary:
        "Recurso Especial que consolidou jurisprudência sobre revisão de juros bancários abusivos.",
    whyApplies:
        "Reforça o argumento central do caso, estabelecendo que a simples demonstração de abusividade já é suficiente para a revisão contratual.",
  ),
];
