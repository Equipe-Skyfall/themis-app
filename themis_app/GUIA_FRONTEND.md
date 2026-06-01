# Guia de Integração Frontend — Themis API

Base URL: `http://localhost:8000`  
Todas as rotas exigem header: `Authorization: Bearer <JWT_TOKEN>`  
Prefixo de todas as rotas: `/petition`

---

## Autenticação

Todas as requisições precisam de um JWT válido no header `Authorization`.  
O token contém o `userId` que identifica o usuário em todas as operações.

---

## Polling (Operações Assíncronas)

Vários endpoints retornam um `job_id` e processam em background.  
O frontend deve fazer polling até o job terminar.

**Endpoint de polling:**
```
GET /petition/case-status/{job_id}
```

**Respostas possíveis:**
```json
{"status": "processing"}
```
```json
{"status": "done", "result": { ... }}
```
```json
{"status": "error", "detail": "mensagem de erro"}
```

**Implementação sugerida (Flutter):**
```dart
Future<Map<String, dynamic>> pollJob(String jobId) async {
  while (true) {
    await Future.delayed(Duration(seconds: 3));
    final response = await http.get(
      Uri.parse('$baseUrl/petition/case-status/$jobId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (data['status'] != 'processing') return data;
  }
}
```

---

## Frente 1 — Assistente ao Advogado (Geração de Petição)

### 1. Gerar Petição Inicial

Envia uma descrição do caso (texto) + PDF opcional. O backend busca precedentes, classifica e gera uma petição estruturada.

**Request:**
```
POST /petition/generate
Content-Type: multipart/form-data
```

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `case_description` | text | sim | Descrição textual do caso |
| `orgao_filter` | text | não | Filtrar precedentes por órgão (ex: "STF", "TST") |
| `file` | file (PDF) | não | Documento PDF anexo (contrato, correspondência, etc.) |

**Response:**
```json
{"job_id": "abc123"}
```

**Resultado do polling (status: "done"):**
```json
{
  "status": "done",
  "result": {
    "petition_text": "## I — FATOS\n...\n## II — FUNDAMENTOS JURÍDICOS\n...\n## III — TESE CENTRAL\n...\n## IV — PEDIDOS\n...",
    "precedent_results": [
      {
        "id": "stf-sum-331",
        "tipo": "SUM",
        "orgao": "STF",
        "situacao": "vigente",
        "tese": "...",
        "questao": "...",
        "textoEmenta": "...",
        "textoDecisao": "...",
        "relevance_label": "aplicavel",
        "explanation": "Este precedente se aplica porque...",
        "similarity_score": 85
      }
    ],
    "weak_precedents": false
  }
}
```

**Campos importantes:**
- `petition_text` — texto completo da petição em Markdown
- `precedent_results` — lista de precedentes encontrados e classificados
- `relevance_label` — "aplicavel", "possivelmente aplicavel" ou "nao aplicavel"
- `weak_precedents` — `true` se nenhum precedente forte foi encontrado
- `similarity_score` — 0 a 100, quão similar é ao caso

---

### 2. Regenerar Petição

O usuário edita a petição e quer regenerar com novos precedentes. O backend usa o texto editado para buscar precedentes novos e gerar uma nova versão.

**Request:**
```
POST /petition/regenerate
Content-Type: application/json
```

```json
{
  "case_description": "Descrição original do caso...",
  "petition_text": "Texto editado da petição pelo usuário...",
  "instructions": "Adicione pedido de danos morais e tutela de urgência"
}
```

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `case_description` | string | sim | Descrição original do caso |
| `petition_text` | string | sim | Texto da petição (editado ou não) |
| `instructions` | string | não | Instruções do advogado para a regeneração |

**Response:**
```json
{"job_id": "def456"}
```

**Resultado do polling:** mesmo formato que `/generate` — retorna nova `petition_text` + novos `precedent_results`.

---

### 3. Buscar Precedentes (Manual)

Busca rápida de precedentes por texto livre. Síncrono (sem polling).

**Request:**
```
POST /petition/search-precedents
Content-Type: application/json
```

```json
{
  "query": "demissão sem justa causa verbas rescisórias"
}
```

**Response:**
```json
{
  "results": [
    {
      "id": "tst-irr-001",
      "tipo": "IRR",
      "orgao": "TST",
      "tese": "...",
      "textoEmenta": "...",
      "similarity_score": 78
    }
  ]
}
```

> Nota: este endpoint NÃO classifica os precedentes (sem `relevance_label`). É apenas uma busca por similaridade.

---

### 4. Histórico de Petições Geradas

**Request:**
```
GET /petition/generated-history
```

**Response:**
```json
{
  "history": [
    {
      "id": "6650a1b2c3d4e5f6a7b8c9d0",
      "case_description": "Trabalhador demitido...",
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

## Frente 2 — Assistente ao Magistrado (Análise de Caso)

### 1. Analisar Caso (PDF completo)

Envia um PDF de processo judicial completo. O backend segmenta, resume, busca precedentes e gera uma minuta de sentença.

**Request:**
```
POST /petition/analyze-case
Content-Type: multipart/form-data
```

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `file` | file (PDF) | sim | PDF do processo judicial |

**Response:**
```json
{"job_id": "ghi789"}
```

**Resultado do polling (status: "done"):**
```json
{
  "status": "done",
  "result": {
    "case_summary": "Este processo trata de uma ação de...",
    "documents": [
      {
        "type": "peticao_inicial",
        "title": "Petição Inicial - Reclamação Trabalhista",
        "start_page": 1,
        "end_page": 45,
        "summary": "O autor alega que..."
      },
      {
        "type": "contestacao",
        "title": "Contestação da Ré",
        "start_page": 46,
        "end_page": 120,
        "summary": "A ré contesta..."
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

**Campos importantes:**
- `case_summary` — resumo geral do caso
- `documents` — lista de peças processuais identificadas (máx 6 tipos)
  - Tipos possíveis: `peticao_inicial`, `contestacao`, `replica`, `sentenca`, `apelacao`, `contrarrazoes`
- `petition_summary` — resumo detalhado da petição inicial
- `precedent_results` — precedentes encontrados e classificados
- `minuta` — minuta de sentença gerada (relatório + fundamentação + dispositivo)
- `weak_precedents` — `true` se nenhum precedente forte foi encontrado

---

### 2. Endpoint de Teste (Mock)

Para desenvolvimento frontend sem gastar API. Simula o polling com delay de 15s e retorna um resultado real do banco.

**Request:**
```
POST /petition/analyze-case-test
Content-Type: multipart/form-data
```

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `file` | file (PDF) | sim | Qualquer PDF (será ignorado) |

**Response e polling:** idêntico ao `/analyze-case`.

---

### 3. Histórico de Análises (Frente 2)

**Request:**
```
GET /petition/history
```

**Response:**
```json
{
  "history": [
    {
      "id": "6650a1b2c3d4e5f6a7b8c9d0",
      "filename": "processo_123.pdf",
      "timestamp": "2026-05-14T10:30:00Z",
      "summary": "Resumo do caso...",
      "results": [...]
    }
  ]
}
```

---

## Fluxo Sugerido — Frente 1 (Flutter)

```
┌─────────────────────────────────────────────────┐
│  1. Tela: Novo Caso                             │
│     - Campo de texto: descrição do caso         │
│     - Botão: anexar PDF (opcional)              │
│     - Dropdown: filtro por órgão (opcional)     │
│     - Botão: "Gerar Petição"                   │
│       → POST /petition/generate                 │
│       → Mostra loading + polling                │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  2. Tela: Resultado                             │
│     - Petição gerada (texto editável)           │
│     - Lista de precedentes (com labels)         │
│     - Flag: precedentes fracos (aviso)          │
│     - Botão: "Regenerar"                        │
│       → Abre tela de edição                     │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  3. Tela: Edição / Regeneração                  │
│     - Texto da petição editável                 │
│     - Campo: instruções adicionais              │
│     - Botão: "Regenerar com novos precedentes"  │
│       → POST /petition/regenerate               │
│       → Polling + mostra novo resultado         │
└─────────────────────────────────────────────────┘
```

---

## Fluxo Sugerido — Frente 2 (Flutter)

```
┌─────────────────────────────────────────────────┐
│  1. Tela: Upload do Processo                    │
│     - Botão: selecionar PDF                     │
│     - Botão: "Analisar"                         │
│       → POST /petition/analyze-case             │
│       → Mostra loading + polling                │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  2. Tela: Resultado da Análise                  │
│     - Resumo do caso (case_summary)             │
│     - Lista de documentos identificados         │
│       (tipo, páginas, resumo de cada)           │
│     - Precedentes encontrados (com labels)      │
│     - Minuta de sentença                        │
│     - Flag: precedentes fracos (aviso)          │
└─────────────────────────────────────────────────┘
```

---

## Notas Importantes

1. **Polling interval:** 3 segundos é um bom intervalo. Não faça mais rápido que 2s.
2. **Timeout:** A geração de petição leva ~30-60s. A análise de caso pode levar 2-5 minutos para PDFs grandes.
3. **Erros:** Sempre trate `status: "error"` e mostre a mensagem de `detail` ao usuário.
4. **Markdown:** `petition_text` e `minuta` são Markdown. Use um renderer (ex: `flutter_markdown`).
5. **weak_precedents:** Se `true`, mostre um aviso ao usuário de que os precedentes encontrados não são fortes.
6. **relevance_label:**
   - `"aplicavel"` → badge verde
   - `"possivelmente aplicavel"` → badge amarelo
   - `"nao aplicavel"` → não deveria aparecer (já filtrado)
7. **O `/generate` usa multipart/form-data** (não JSON), pois aceita arquivo. No Flutter use `MultipartRequest`.
8. **O `/regenerate` usa JSON** (application/json), pois não aceita arquivo.
