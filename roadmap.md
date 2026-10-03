# Roadmap

- [x] **CONCLUÍDO** — Além da tabela nutricional no formato padrão, ter a versão em **texto linear**.
  - `nutrition_facts_linear/1` em `lib/kcal_web/components/nutrition_components.ex`, exibida na página do componente (valores por porção + %VD, na ordem Anvisa).

- [x] **CONCLUÍDO** — Tabela/declaração de ingredientes seguindo o padrão brasileiro (os **primeiros ingredientes** — maior quantidade — **vêm primeiro**).
  - Declaração "Ingredientes: …" em ordem decrescente de massa dentro do rótulo, e a tabela de ingredientes da página também ordenada por peso decrescente. Helper: `ingredient_names_desc/1`.

- [x] **CONCLUÍDO (parcial)** — Alertas "ALTO EM" da rotulagem nutricional frontal (IN 75/2020).
  - Selos de **gordura saturada** (≥ 6 g/100 g) e **sódio** (≥ 600 mg/100 g) implementados e exibidos no rótulo. Lógica em `front_warnings/1`.
  - ⚠️ **Pendência de dados:** "alto em açúcar adicionado" (≥ 15 g/100 g) **não** pode ser calculado — as bases TACO/TBCA não trazem açúcar (nem total nem adicionado), e o schema `Food` não tem esse campo. Para habilitar esse selo é preciso adicionar um campo de açúcar adicionado por alimento (migração + origem do dado). O código já está pronto para incluí-lo assim que o dado existir.

- [x] **CONCLUÍDO** — busca ignorando acentos e maiúsculas: "açúcar" ↔ "acucar".
  - Extensão `unaccent` (migração `enable_unaccent`) + `ilike(unaccent(nome), unaccent(termo))` em `search_foods/2` e `search_components/3` (ranqueamento por `similarity(unaccent(...), unaccent(...))`).

- [x] **CONCLUÍDO** — ordem na visualização do componente invertida: **Alertas → Tabela nutricional → Ingredientes** (como nos produtos). A lista de ingredientes aparece como **declaração em texto** ("Ingredientes: …, … e ….", ordem decrescente de massa) no estilo dos rótulos reais, seguida do detalhamento por ingrediente. `ingredient_declaration/1`.

- [x] **CONCLUÍDO** — nomes de ingredientes do TACO ("Queijo, cru") deixam de parecer ingredientes separados na lista: `ingredient_label/1` achata as vírgulas internas ("Queijo cru"), aplicado tanto na declaração quanto na tabela de detalhamento.

- [x] **CONCLUÍDO** — todos os 5 modelos de tabela do Anexo IX disponíveis na visualização: vertical, vertical quebrada, horizontal, **horizontal quebrada** e linear (Anexo XIII). Selos "ALTO EM" fiéis à malha construtiva (Anexo XVII), adaptando-se a 1/2/3 nutrientes.

