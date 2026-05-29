# Respostas da API & Exemplos de Petição — Themis

Base URL: `https://themis-back.onrender.com`  
Auth: `https://auth.skytrack.space`  
Todas as rotas: `Authorization: Bearer <JWT_TOKEN>`

---

## Frente 1 — Assistente ao Advogado

### POST `/petition/generate` → Gera petição inicial

**Envio (multipart/form-data):**
| Campo | Tipo | Obrigatório |
|---|---|---|
| `case_description` | text | ✅ |
| `orgao_filter` | text | ❌ |
| `file` | PDF | ❌ |

**Resposta imediata:**
```json
{ "job_id": "abc123" }
```

**Polling: GET `/petition/case-status/{job_id}`**

```json
{ "status": "processing" }
```
```json
{ "status": "error", "detail": "mensagem de erro" }
```
```json
{
  "status": "done",
  "result": {
    "petition_text": "## I — FATOS\n...\n## II — FUNDAMENTOS JURÍDICOS\n...\n## III — TESE CENTRAL\n...\n## IV — PEDIDOS\n...",
    "precedent_results": [
      {
        "id": "tst-sum-443",
        "tipo": "SUM",
        "orgao": "TST",
        "situacao": "vigente",
        "tese": "Texto da tese jurídica...",
        "questao": "Questão central do precedente...",
        "textoEmenta": "Ementa do acórdão...",
        "textoDecisao": "Texto da decisão...",
        "relevance_label": "aplicavel",
        "explanation": "Este precedente se aplica porque...",
        "similarity_score": 85
      }
    ],
    "weak_precedents": false
  }
}
```

**Campos que o app usa:**
| Campo | Onde aparece |
|---|---|
| `petition_text` | Corpo principal (Markdown, editável) |
| `precedent_results` | Lista de cards de precedentes |
| `precedent_results[].relevance_label` | Badge verde/amarelo por card |
| `precedent_results[].similarity_score` | Percentual de similaridade por card |
| `weak_precedents` | Alerta amarelo no topo se `true` |

**`relevance_label` → cor do badge:**
- `"aplicavel"` → 🟢 verde
- `"possivelmente aplicavel"` → 🟡 amarelo
- `"nao aplicavel"` → filtrado/não exibido

---

### POST `/petition/regenerate` → Regenera petição com instruções

**Envio (application/json):**
```json
{
  "case_description": "Descrição original do caso...",
  "petition_text": "Texto atual da petição (editado ou não)...",
  "instructions": "Adicione pedido de danos morais e tutela de urgência"
}
```

**Resposta imediata:** `{ "job_id": "def456" }`

**Polling:** mesmo formato de `/generate` — retorna nova `petition_text` + novos `precedent_results`.

---

### GET `/petition/generated-history` → Histórico de petições geradas

```json
{
  "history": [
    {
      "id": "6650a1b2c3d4e5f6a7b8c9d0",
      "case_description": "Trabalhador demitido sem justa causa...",
      "petition_text": "## I — FATOS\n...",
      "precedent_results": [...],
      "weak_precedents": false,
      "instructions": null,
      "timestamp": "2026-05-14T10:30:00Z"
    }
  ]
}
```

---

## Frente 2 — Assistente ao Magistrado

### POST `/petition/analyze-case` → Analisa processo judicial (produção)
### POST `/petition/analyze-case-test` → Versão de teste (15s delay, dados reais do banco)

**Envio (multipart/form-data):**
| Campo | Tipo | Obrigatório |
|---|---|---|
| `file` | PDF | ✅ |

**Resposta imediata:** `{ "job_id": "ghi789" }`

**Polling result:**
```json
{
  "status": "done",
  "result": {
    "case_summary": "Este processo trata de uma ação de reclamação trabalhista...",
    "documents": [
      {
        "type": "peticao_inicial",
        "title": "Petição Inicial - Reclamação Trabalhista",
        "start_page": 1,
        "end_page": 45,
        "summary": "O autor alega que foi demitido sem justa causa..."
      },
      {
        "type": "contestacao",
        "title": "Contestação da Ré",
        "start_page": 46,
        "end_page": 120,
        "summary": "A ré contesta alegando justa causa..."
      }
    ],
    "total_pages": 500,
    "petition_summary": "Resumo detalhado da petição inicial...",
    "precedent_results": [
      {
        "id": "tst-sum-443",
        "tipo": "SUM",
        "orgao": "TST",
        "tese": "...",
        "relevance_label": "aplicavel",
        "explanation": "...",
        "similarity_score": 90
      }
    ],
    "minuta": "## RELATÓRIO\n...\n## FUNDAMENTAÇÃO\n...\n## DISPOSITIVO\n...",
    "weak_precedents": false
  }
}
```

**Campos que o app usa:**
| Campo | Onde aparece |
|---|---|
| `case_summary` | Resumo do caso (caixa azul) |
| `documents` | Lista de peças processuais identificadas |
| `petition_summary` | Resumo detalhado da petição |
| `precedent_results` | Cards de precedentes com badges |
| `minuta` | Texto da minuta de sentença (Markdown) |
| `weak_precedents` | Alerta amarelo se `true` |

**Tipos de documentos possíveis:**
`peticao_inicial` · `contestacao` · `replica` · `sentenca` · `apelacao` · `contrarrazoes`

---

### GET `/petition/history` → Histórico de análises do Juiz

```json
{
  "history": [
    {
      "id": "6650a1b2c3d4e5f6a7b8c9d0",
      "filename": "processo_123.pdf",
      "timestamp": "2026-05-14T10:30:00Z",
      "summary": "Ação trabalhista por demissão sem justa causa...",
      "results": [...]
    }
  ]
}
```

---

## Polling — Funcionamento Geral

```
POST /petition/generate  →  { job_id }
                              ↓
GET /petition/case-status/{job_id}  (a cada 3s)
                              ↓
{ status: "processing" }  →  continua polling
{ status: "done", result: {...} }  →  exibe resultado
{ status: "error", detail: "..." }  →  exibe erro ao usuário
```

**Timeout:** geração ~30-60s · análise de processo ~2-5min para PDFs grandes.

---

---

## Exemplos de Casos para Testar a Geração de Petição

Cole qualquer um desses no campo de descrição do caso na tela "Nova Petição".

---

### Exemplo 1 — Direito Trabalhista: Demissão sem justa causa
```
Meu cliente, João Carlos da Silva, trabalhou por 7 anos na empresa Transportes Brasil Ltda como motorista. Em março de 2026, foi demitido sem justa causa, porém a empresa se recusou a pagar as verbas rescisórias completas. Não foram pagos: aviso prévio indenizado proporcional ao tempo de serviço, 13º salário proporcional, férias proporcionais + 1/3, FGTS + multa de 40%, além de horas extras realizadas nos últimos 3 anos que nunca foram quitadas (trabalhava 10h/dia sem receber o adicional). O trabalhador também não recebeu o seguro-desemprego pois a empresa atrasou a entrega das guias. Solicitar tutela de urgência para bloqueio de bens.
```

---

### Exemplo 2 — Direito do Consumidor: Produto defeituoso e dano moral
```
A autora adquiriu uma geladeira da marca FrostMax em janeiro de 2025 por R$ 3.800,00. O produto apresentou defeito de fabricação (compressor com vício oculto) após 3 meses de uso, dentro da garantia legal de 90 dias para produtos duráveis. A empresa foi notificada duas vezes para fazer o reparo mas não compareceu. O alimento estragou causando prejuízo material de R$ 800,00 em mantimentos. A autora ficou sem geladeira por 45 dias, período em que passou constrangimentos e teve sua rotina doméstica gravemente prejudicada. Pede: substituição do produto por outro novo da mesma espécie, ressarcimento dos danos materiais (R$ 800,00) e indenização por danos morais.
```

---

### Exemplo 3 — Direito Civil: Cobrança de contrato de prestação de serviços
```
A empresa Contratante Alfa Ltda contratou os serviços de consultoria da empresa Beta Serviços S/A pelo valor de R$ 45.000,00, conforme contrato assinado em 10/01/2026. Os serviços foram integralmente prestados e entregues dentro do prazo contratual em 15/02/2026. A contratante recebeu todos os relatórios e atestou a entrega por e-mail. Contudo, apesar de três cobranças formais e do vencimento da fatura em 01/03/2026, o pagamento não foi realizado. A empresa contratante alega verbalmente insatisfação com o serviço sem apresentar fundamento. Pedir: pagamento da dívida principal (R$ 45.000,00), correção monetária pelo IPCA desde o vencimento, juros de mora de 1% ao mês, multa contratual de 10% e honorários advocatícios de 20%.
```

---

### Exemplo 4 — Direito Previdenciário: Aposentadoria por invalidez negada
```
Meu cliente, Pedro Almeida, 52 anos, trabalhou 28 anos como pedreiro na construção civil. Em 2024 sofreu um acidente de trabalho que resultou em fratura exposta no tornozelo direito com lesão de tendão e nervo, sendo submetido a três cirurgias. Possui laudo médico atestando incapacidade permanente para exercer a função habitual e qualquer atividade que exija esforço físico. O INSS negou o benefício de aposentadoria por invalidez alegando que a incapacidade não é total. O perito do INSS realizou avaliação de apenas 5 minutos. Requerer na via judicial a concessão do benefício de aposentadoria por invalidez com DIB na data do requerimento administrativo (02/10/2024) e o pagamento dos atrasados desde então.
```

---

### Exemplo 5 — Direito de Família: Alimentos
```
A autora, mãe de dois filhos menores (8 e 11 anos), se separou do réu em 2024. O ex-cônjuge, engenheiro civil com salário de aproximadamente R$ 12.000,00 mensais conforme comprovantes de renda, está pagando apenas R$ 600,00 mensais de pensão alimentícia por conta própria, alegando dificuldades financeiras, embora mantenha carro de luxo e viagens internacionais. As crianças residem com a mãe, que arca com escola particular (R$ 900,00/mês cada), plano de saúde, alimentação, vestuário e todas as despesas. Pedir fixação de alimentos no valor de 30% dos rendimentos líquidos do réu, com aplicação imediata via tutela de urgência, e fixação de multa diária por descumprimento.
```

---

### Exemplo 6 — Direito do Inquilinato: Despejo por falta de pagamento
```
O locador Paulo Mendes alugou seu imóvel residencial localizado na Rua das Flores, 100, São Paulo/SP, ao locatário Carlos Eduardo pelo valor de R$ 2.200,00 mensais, com contrato de 30 meses iniciado em março de 2024. O locatário está inadimplente há 4 meses consecutivos (fevereiro a maio de 2026), totalizando R$ 8.800,00 de aluguel em atraso, mais taxas de condomínio e IPTU que também são de responsabilidade do locatário conforme contrato. O locador notificou extrajudicialmente por carta registrada e o locatário ignorou. Não há fiador nem caução no contrato. Pedir: ação de despejo por falta de pagamento cumulada com cobrança, com pedido liminar de desocupação em 15 dias.
```

---

### Dicas para melhores resultados

- **Seja específico**: inclua datas, valores, nomes fictícios e fatos concretos
- **Mencione o pedido**: diga o que quer (indenização, tutela, cobrança etc.)
- **Filtro por órgão**: use para direcionar precedentes (ex: `TST` para trabalhista, `STJ` para civil/consumidor)
- **Regenerar**: se não gostar do resultado, abra o bottom sheet "Regenerar" e adicione instruções como *"enfatize o dano moral"* ou *"adicione fundamentos sobre tutela de urgência"*
