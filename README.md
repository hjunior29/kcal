# Kcal — Cálculo Nutricional de Receitas e Refeições

Aplicação web (Elixir · Phoenix · LiveView · Ecto · PostgreSQL) para montar
**Componentes** (receitas/refeições) a partir de alimentos base das tabelas
**TACO** e **TBCA**, calcular seus macros e gerar uma **Tabela Nutricional no
padrão Anvisa** exportável como imagem.

Sem login, sem autenticação, sem controle de peso: o usuário cai direto na tela
principal de criação e listagem de componentes.

Estilo **brutalista/minimalista**: cantos retos (`rounded-none`), sem sombras,
sem gradientes. Beleza pelo espaçamento e tipografia.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Linguagem / runtime | Elixir 1.18 / Erlang OTP 28 |
| Web | Phoenix 1.8 + Phoenix LiveView 1.1 |
| Dados | Ecto 3 + PostgreSQL |
| CSS | Tailwind v4 (+ daisyUI, neutralizado para o visual brutalista) |
| Export de imagem | `html2canvas` (client-side, via CDN) |

---

## Como rodar

Pré-requisitos: Elixir/Erlang, Node, e um PostgreSQL acessível em
`localhost:5432` com usuário/senha `postgres`/`postgres` (ajuste em
`config/dev.exs` se necessário). Via Docker:

```bash
docker run -d --name kcal-pg -p 5432:5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=postgres \
  postgres:16-alpine
```

Então:

```bash
mix setup          # deps + cria/migra o banco + SEED (TACO/TBCA) + assets
mix phx.server     # http://localhost:4000
```

`mix setup` já popula o banco com **8 unidades de medida** e **600 alimentos
base** — a **tabela TACO completa** (596 alimentos, 4ª ed. NEPA/UNICAMP) mais
um suplemento curado de industrializados da **TBCA**. Os dados vêm dos CSVs
versionados em `priv/repo/data/` (`taco_alimentos.csv` + `taco_acidos_graxos.csv`,
unidos pelo número do alimento), processados por `priv/repo/seeds.exs`.

Opcional — dados de demonstração (cria "Frango com marinado oriental" e uma
"Marmita fitness" que **aninha** o primeiro):

```bash
mix run priv/repo/sample_components.exs
```

Testes:

```bash
mix test           # cálculo puro + fluxo LiveView do builder
```

---

## Arquitetura

```
lib/kcal/nutrition/            CONTEXTO DE DOMÍNIO
├── food.ex                     Alimento base (TACO/TBCA), nutrientes por 100 g
├── measure_unit.ex             Unidade de medida (g, ml, colher…, unidade)
├── component.ex                Componente (receita/refeição) + has_many :items
├── component_item.ex           Linha: aponta p/ food XOR child_component (aninhamento)
├── nutrients.ex                Value object: struct + add/scale/sum (ordem Anvisa)
└── calculator.ex               Matemática pura: conversão + agregação aninhada
lib/kcal/nutrition.ex          API pública do contexto (CRUD, busca, relatório)

lib/kcal_web/
├── components/nutrition_components.ex   <.nutrition_facts> — rótulo Anvisa
├── components/core_components.ex        + header_bar/1, brutal_link/1 (brutalismo)
└── live/component_live/
    ├── index.ex               Dashboard (lista + filtro dinâmico)
    ├── form.ex                Builder (busca dinâmica, medidas, aninhamento, preview)
    └── show.ex                Detalhe + tabela Anvisa + exportar imagem

assets/js/hooks/nutrition_export.js      Hook html2canvas (baixar / copiar PNG)
```

### 1) Modelagem do banco (Schemas Ecto)

Quatro tabelas. O aninhamento usa uma **tabela de junção self-referencing**
(`component_items`), e não uma coluna `parent_id` no próprio componente —
isso permite que a mesma linha referencie **ou** um alimento base **ou** outro
componente, com quantidade e unidade próprias.

```
foods (TACO/TBCA, valores por 100 g)
  energy_kcal, carbohydrate_g, protein_g, total_fat_g,
  saturated_fat_g, trans_fat_g, fiber_g, sodium_mg

measure_units
  name, abbreviation, grams_per_unit (nil p/ "unidade"), kind(mass|volume|count)

components (receita/refeição)
  name, description, serving_size_g, servings_label

component_items  ── pertence a um component (pai)
  quantity, grams_per_unit_override, position
  food_id           ─┐ exatamente UM dos dois
  child_component_id ─┘ (CHECK xor no banco)
  measure_unit_id
```

Integridade garantida no banco por **check constraints**:
`(food_id IS NULL) <> (child_component_id IS NULL)` (exatamente um alvo) e
`child_component_id <> component_id` (sem auto-referência direta). Ciclos
indiretos (A→B→A) são barrados no contexto (`reject_cycles/2` + `descendant?/2`).

### 2) O motor de cálculo (`Calculator`)

Toda linha vira **gramas** e depois um perfil absoluto de nutrientes:

- **Alimento base:** `perfil_por_100g × (gramas / 100)`.
- **Componente aninhado:** perfil absoluto do filho × `(gramas / peso_total_do_filho)`
  — ou seja, uma **fração de massa** da receita-filha. Assim, 200 g de um
  componente cujo preparo total pesa 200 g contribui com 100% dos seus macros.

Conversão de medida: `gramas = quantidade × (override_da_linha ou grams_per_unit)`.
"Unidade" não tem grama padrão (`grams_per_unit: nil`), então o builder pede o
"g por unidade" quando essa medida é escolhida.

A recursão de aninhamento é dirigida por um *loader* (mantém o módulo livre de
`Repo`) e protegida por um conjunto `visited` contra ciclos.

### 3) Tabela Nutricional (padrão Anvisa)

`<.nutrition_facts>` (`nutrition_components.ex`) renderiza HTML limpo com a
**ordem estrita** exigida (RDC 429/2020 + IN 75/2020):

> Valor energético → Carboidratos → Proteínas → Gorduras totais →
> Gorduras saturadas → Gorduras trans → Fibra alimentar → Sódio

Duas colunas (**100 g** e **porção**) + coluna **%VD** calculada sobre a porção,
usando os Valores Diários de referência da IN 75/2020. Energia mostrada em
`kcal` e `kJ`. Visual brutalista (bordas pretas grossas, cantos retos).

O elemento da tabela carrega `data-export-target`; o hook `NutritionExport`
(`html2canvas`) rasteriza em PNG para **Baixar imagem** ou **Copiar imagem**
(com fallback para download quando a área de transferência não aceita imagens).

> ⚠️ Os valores nutricionais (TACO 4ª ed. NEPA/UNICAMP e TBCA/USP-FoRC) são
> aproximados e de uso educacional. Açúcares totais/adicionados não são
> modelados (não estão no escopo dos campos pedidos).

---

## Fluxo do builder (LiveView)

A lista de ingredientes vive em **estado do servidor** (`@items`), não nos
params do formulário — por isso a busca, a adição e a edição são instantâneas e
o rótulo Anvisa à direita é recalculado a cada mudança (pré-visualização ao
vivo). A busca é trigram-indexada (`pg_trgm`) para filtrar a base em tempo real.
