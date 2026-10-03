<p align="center">
  <img src="priv/static/images/logo.png" alt="Kcal Logo" width="130" />
</p>

<h1 align="center">Kcal</h1>

<p align="center">
  <b>Cálculo Nutricional de Receitas & Gerador de Rótulos no Padrão Anvisa</b>
  <br />
  Monte refeições a partir das tabelas oficiais TACO/TBCA, aninhe preparações e gere tabelas nutricionais e selos frontais exportáveis.
</p>

<p align="center">
  <a href="https://kcal.fly.dev">
    <img src="https://img.shields.io/badge/Demo-kcal.fly.dev-10b981?style=for-the-badge&logo=flydotio&logoColor=white" alt="Live Demo" />
  </a>
  <img src="https://img.shields.io/badge/Elixir-1.18-4B275F?style=for-the-badge&logo=elixir&logoColor=white" alt="Elixir" />
  <img src="https://img.shields.io/badge/Phoenix-LiveView%201.1-FD4F00?style=for-the-badge&logo=phoenixframework&logoColor=white" alt="Phoenix LiveView" />
  <img src="https://img.shields.io/badge/PostgreSQL-17-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Tailwind-CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white" alt="Tailwind CSS" />
  <img src="https://img.shields.io/badge/Anvisa-RDC%20429%20%7C%20IN%2075-black?style=for-the-badge" alt="Anvisa Compliance" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <a href="https://kcal.fly.dev"><strong>🌐 Acesse a aplicação em produção &rarr;</strong></a>
</p>

---

## 🥗 Visão Geral

**Kcal** é uma plataforma focada em precisão e simplicidade para cálculo e rotulagem nutricional de alimentos, receitas e marmitas. Desenvolvido para cozinhas profissionais, nutricionistas e entusiastas, o sistema permite compor **Componentes** alimentares a partir de uma base com **cerca de 600 alimentos oficiais (TACO 4ª edição e TBCA)**, agregando macros e micronutrientes com total fidelidade à legislação brasileira de rotulagem (**RDC 429/2020** e **IN 75/2020**).

A interface segue uma estética **brutalista e minimalista** (bordas pretas sólidas, cantos retos, alto contraste e tipografia direta), sem fricções: sem telas de login ou cadastros lentos, com busca dinâmica instantânea e exportação dos rótulos prontos em imagem PNG.

---

## 🏷️ Conformidade Completa com a Anvisa

O sistema implementa rigorosamente as normas vigentes da Anvisa para rotulagem de alimentos embalados:

### 1. Cinco Modelos Oficiais de Tabela (Anexo IX e XIII)
Alterne entre todos os layouts previstos por norma para caber em qualquer formato de embalagem:
- **Vertical Padrão:** Layout clássico de coluna única com 100 g, porção e %VD.
- **Vertical Quebrada:** Formato vertical dividido em duas colunas para economia de altura.
- **Horizontal:** Formato em linhas largas, ideal para fundos de caixas e pacotes compridos.
- **Horizontal Quebrada:** Formato horizontal particionado para embalagens com pouco espaço vertical.
- **Linear (Anexo XIII):** Formato em texto contínuo corrido, reservado para embalagens cuja área visível de rotulagem seja menor que 100 cm².

### 2. Rotulagem Nutricional Frontal ("ALTO EM" — Anexo XVII)
- Exibição automática do selo da **Lupa Oficial da Anvisa** quando os limites críticos são ultrapassados:
  - **Gordura Saturada:** $\ge 6\text{ g} / 100\text{ g}$
  - **Sódio:** $\ge 600\text{ mg} / 100\text{ g}$
- Malha construtiva responsiva que renderiza o formato correto (1, 2 ou 3 alertas combinados).

### 3. Declaração Legal de Ingredientes
- Geração automática da linha *"Ingredientes: Item A, Item B e Item C."* disposta estritamente em **ordem decrescente de peso/quantidade**.
- Tratamento automático de descrições da base TACO (ex.: `"Queijo, cru"` é normalizado para evitar que pareçam dois ingredientes separados na lista).

### 4. Ordem Estrita dos Nutrientes
Valores por 100 g e por Porção com cálculo de %VD pelos Valores Diários de referência oficiais:
> Valor Energético (kcal e kJ) &rarr; Carboidratos &rarr; Proteínas &rarr; Gorduras Totais &rarr; Gorduras Saturadas &rarr; Gorduras Trans &rarr; Fibras Alimentares &rarr; Sódio

---

## 🧮 Motor de Cálculo & Aninhamento Recursivo

- **Aninhamento Real:** Uma receita pronta (ex.: *"Frango com Marinado Oriental"*) pode ser usada diretamente como ingrediente de outra preparação (ex.: *"Marmita Fit Completa"*).
- **Cálculo Proporcional de Fração de Massa:** O sistema calcula o peso final e distribui o perfil nutricional proporcionalmente à massa utilizada na receita mãe.
- **Proteção contra Ciclos:** Algoritmo que previne dependências circulares (A &rarr; B &rarr; A).
- **Conversão de Medidas:** Suporte a unidades de massa (g, kg), volume (ml, l, colher de chá, colher de sopa, xícara) e unidades com peso configurável.
- **Busca Sem Acento e Trigramas:** O picker de ingredientes utiliza `unaccent` e similaridade com `pg_trgm`, permitindo buscar "acucar" e encontrar "Açúcar" instantaneamente.

---

## 🛠️ Stack Tecnológica

- **Backend / Runtime:** [Elixir 1.18](https://elixir-lang.org/) / Erlang OTP 28
- **Framework Web:** [Phoenix Framework 1.8](https://www.phoenixframework.org/)
- **Tempo Real & UI Reativa:** [Phoenix LiveView 1.1](https://hexdocs.pm/phoenix_live_view/)
- **Banco de Dados:** [PostgreSQL 17](https://www.postgresql.org/) com extensões `pg_trgm` e `unaccent`
- **ORM / Migrations:** [Ecto 3.13](https://hexdocs.pm/ecto/)
- **Estilização:** [Tailwind CSS](https://tailwindcss.com/) & [daisyUI](https://daisyui.com/)
- **Exportação Gráfica:** `html2canvas` (rasterização de alta precisão no client-side para copiar ou baixar PNG)
- **Infraestrutura:** Docker & [Fly.io](https://fly.io)

---

## 📂 Arquitetura da Aplicação

```
lib/kcal/nutrition/            CONTEXTO DE DOMÍNIO
├── food.ex                     Alimento base (TACO/TBCA), nutrientes por 100 g
├── measure_unit.ex             Unidade de medida (g, ml, colheres, xícara, unidade)
├── component.ex                Componente (receita/refeição) + has_many :items
├── component_item.ex           Linha: aponta p/ food XOR child_component (aninhamento)
├── nutrients.ex                Value object: struct de nutrientes + somas e escalas
├── calculator.ex               Matemática pura: conversão de unidades + agregação
└── release.ex                  Tarefas de migração e seeding para releases de produção
lib/kcal/nutrition.ex          API pública do contexto (CRUD, busca e relatórios)

lib/kcal_web/
├── components/nutrition_components.ex   <.nutrition_facts_*> — 5 modelos Anvisa + Alertas
├── components/core_components.ex        Componentes UI brutalistas
└── live/component_live/
    ├── index.ex               Dashboard de receitas com filtro em tempo real
    ├── form.ex                Builder interativo com preview ao vivo
    └── show.ex                Visualização completa + seleção de modelos + exportação PNG
```

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- Elixir 1.15+ e Erlang/OTP 26+
- PostgreSQL rodando localmente (porta 5432, padrão `postgres`/`postgres`)

Via Docker:
```bash
docker run -d --name kcal-postgres -p 5432:5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=kcal_dev \
  postgres:17-alpine
```

### Inicialização

```bash
# 1. Clone o repositório
git clone https://github.com/hjunior29/kcal.git
cd kcal

# 2. Instale dependências, crie o banco, rode as migrations e popule o seed oficial TACO
mix setup

# 3. Inicie o servidor
mix phx.server
```

Acesse [`http://localhost:4000`](http://localhost:4000) no navegador.

Para carregar receitas de exemplo prontas (Marmita com itens aninhados):
```bash
mix run priv/repo/sample_components.exs
```

Para rodar os testes unitários e de integração:
```bash
mix test
```

---

## ☁️ Deploy no Fly.io

O repositório já inclui configuração completa para deploy automatizado:
- [`fly.toml`](fly.toml): Configuração de máquina com autostop/autostart e cluster regional (`gru`).
- [`Dockerfile`](Dockerfile): Build multi-stage seguro baseado em Debian Slim.
- [`rel/overlays/bin/migrate`](rel/overlays/bin/migrate): Roda automaticamente as migrações e o seed de dados antes de iniciar o servidor.

Para fazer deploy manual pelo CLI do Fly:
```bash
fly deploy --remote-only -a kcal
```

---

<p align="center">
  Desenvolvido por <a href="https://github.com/hjunior29">Helder Lima (@hjunior29)</a>
</p>
