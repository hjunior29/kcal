# Pesquisa: fontes de dados de composição nutricional (Brasil)

> Documento de histórico. Registra a pesquisa feita para ampliar a base de
> alimentos do projeto (de 64 alimentos curados para a **tabela TACO completa**),
> as opções avaliadas, links e a decisão tomada.
>
> Data: 2026-06-25

## Contexto / problema

O seed inicial trazia apenas **64 alimentos** curados à mão — pouco para cobrir
boa parte da culinária brasileira. O objetivo passou a ser ter uma **coleção
grande e confiável** de alimentos, idealmente a **TACO completa**, incluindo os
campos exigidos pela tabela nutricional Anvisa: **kcal, carboidratos, proteínas,
gorduras totais, gorduras saturadas, gorduras trans, fibra alimentar e sódio**.

O ponto crítico: a maioria dos datasets abertos só traz os **macros básicos** e
**não** traz **gordura saturada e trans** separadamente — campos obrigatórios no
rótulo Anvisa.

## Opções avaliadas

| Fonte | Tamanho aprox. | Cobre sat/trans? | Acesso | Veredito |
|---|---|---|---|---|
| **TACO** (NEPA/UNICAMP, 4ª ed., 2011) | ~597 alimentos | ✅ (em tabela separada de ácidos graxos) | CSV/JSON em repos GitHub | ✅ **escolhida** |
| **TBCA** (USP / FoRC / BRASILFOODS) | ~5.000+ (inclui industrializados e preparações) | parcial | site sem download aberto; requer web scraping | suplemento futuro |
| **Open Food Facts** | global (produtos com código de barras) | depende do produto | API aberta | bom p/ industrializados de marca |
| **IBGE / POF** (tabelas de medidas e composição) | tabelas variadas | parcial | PDFs / planilhas | referência secundária |

### 1. TACO — Tabela Brasileira de Composição de Alimentos (escolhida)

Desenvolvida pelo Núcleo de Estudos e Pesquisas em Alimentação (NEPA) da
UNICAMP. É a referência oficial brasileira para alimentos in natura e preparações
caseiras. ~597 alimentos, valores por 100 g de porção comestível.

Existem vários repositórios no GitHub que digitalizam a TACO. A maioria, porém,
traz **só os macros** na tabela principal. O diferencial do repo escolhido é
disponibilizar **a tabela de ácidos graxos separada**, de onde extraímos
**gordura saturada** e **gordura trans** (soma dos isômeros trans `X18.1t` +
`X18.2t`).

**Repos avaliados:**

- ✅ **[machine-learning-mocha/taco](https://github.com/machine-learning-mocha/taco)** — **usado**. Traz a TACO em CSV em `formatados/` e `tabelas/`, com arquivos separados: `alimentos.csv` (macros, fibra, sódio, minerais, vitaminas), `acidos-graxos.csv` (saturada, mono, poli, isômeros trans) e `aminoacidos.csv`. Estrutura limpa e consumível por R/Python.
- [marcelosanto/tabela_taco](https://github.com/marcelosanto/tabela_taco) — TACO em JSON.
- [danperrout/tabelataco](https://github.com/danperrout/tabelataco) — consulta via JSON interno.
- [brolesi/taco](https://github.com/brolesi/taco) — TACO em formato de banco de dados.
- [elyrio/tacoSQL](https://github.com/elyrio/tacoSQL) — script de conversão da TACO para SQL.
- [raulfdm/taco-api](https://github.com/raulfdm/taco-api) — API GraphQL da TACO.
- [isaquetdiniz/taco-api](https://github.com/isaquetdiniz/taco-api), [sergiodanilojr/taco](https://github.com/sergiodanilojr/taco), [renandspedrosa/tabela-taco-api](https://github.com/renandspedrosa/tabela-taco-api) — APIs REST.

### 2. TBCA — Tabela Brasileira de Composição de Alimentos (USP)

Criada em 1998, mantida de forma integrada pela rede BRASILFOODS, USP e Food
Research Center (FoRC). Tem **muito mais itens que a TACO** (~5.000+), incluindo
**alimentos industrializados** e preparações em medidas caseiras — exatamente o
que a TACO não cobre bem.

- Site oficial: <https://www.tbca.net.br/>
- Busca por componente: <https://www.tbca.net.br/base-dados/busca_componente.php>
- Composição em medidas caseiras: <https://www.tbca.net.br/base-dados/composicao_alimentos.php>

**Limitação:** não há download aberto da base completa; o acesso é via busca no
site. Para incorporar, seria necessário **web scraping**.

- Exemplo de scraper pronto: **[resen-dev/web-scraping-tbca](https://github.com/resen-dev/web-scraping-tbca)** (obtém dados da TBCA e salva em JSON).

### 3. Open Food Facts

Base colaborativa global de produtos com código de barras, API aberta. Útil para
**industrializados de marca** (busca por código de barras / nome comercial).
Pontos de atenção: dados colaborativos podem ser inconsistentes/incompletos.

- Site: <https://br.openfoodfacts.org/>

## Decisão e implementação

**Escolhido:** carregar a **TACO completa** a partir de
[machine-learning-mocha/taco](https://github.com/machine-learning-mocha/taco) +
manter um pequeno **suplemento curado da TBCA** (industrializados comuns:
atum em conserva, requeijão, pasta de amendoim, refrigerante).

Como foi feito:

1. Os dois CSVs foram **versionados** no projeto em `priv/repo/data/`:
   - `taco_alimentos.csv` — macros, fibra alimentar, sódio (e demais colunas).
   - `taco_acidos_graxos.csv` — gordura saturada e isômeros trans.
2. Adicionada a dependência **`nimble_csv`** para parse robusto (descrições têm
   vírgulas dentro de aspas).
3. `priv/repo/seeds.exs` foi reescrito para:
   - parsear os dois CSVs e **uni-los pelo "Número do Alimento"**;
   - somar `X18.1t + X18.2t` para obter a **gordura trans**;
   - tratar `NA` (não disponível) e o placeholder `1e-05` (traço) como `0.0`;
   - **upsert idempotente** por `(source, source_code)` para TACO e por `name`
     para os itens TBCA (re-rodar não duplica).

**Resultado:** **600 alimentos** (596 TACO + 4 TBCA), 18 categorias. Spot-checks
conferem com a fonte (ex.: *Arroz, integral, cozido* = 124 kcal / 2,6 g proteína
/ 0,3 g saturada / 2,7 g fibra / 1 mg sódio).

## Próximos passos possíveis

- **TBCA via scraping** (industrializados/preparações) — usando algo como
  `resen-dev/web-scraping-tbca` como ponto de partida.
- **Open Food Facts** — busca de produtos de marca por nome/código de barras.

## Observações

- Valores são para **uso educacional**; não substituem laudo para fins clínicos
  ou regulatórios.
- Todos os valores são **por 100 g de porção comestível** (base da TACO e TBCA).
