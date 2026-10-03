<p align="center">
  <img src="priv/static/images/logo.png" alt="Kcal Logo" width="130" />
</p>

<h1 align="center">Kcal</h1>

<p align="center">
  <b>Calculadora Nutricional One-Shot & Rotulagem Oficial Anvisa</b>
  <br />
  Uma ferramenta aberta, gratuita e sem cadastro para cálculo e geração de tabelas nutricionais a partir de bases científicas laboratoriais (TACO / UNICAMP e TBCA / USP).
</p>

<p align="center">
  <a href="https://kcal.fly.dev">
    <img src="https://img.shields.io/badge/Demo-kcal.fly.dev-10b981?style=for-the-badge&logo=flydotio&logoColor=white" alt="Live Demo" />
  </a>
  <img src="https://img.shields.io/badge/Elixir-1.18-4B275F?style=for-the-badge&logo=elixir&logoColor=white" alt="Elixir" />
  <img src="https://img.shields.io/badge/Phoenix-LiveView%201.1-FD4F00?style=for-the-badge&logo=phoenixframework&logoColor=white" alt="Phoenix LiveView" />
  <img src="https://img.shields.io/badge/SQLite-Read--Only-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite Read-Only" />
  <img src="https://img.shields.io/badge/Anvisa-RDC%20429%20%7C%20IN%2075-black?style=for-the-badge" alt="Anvisa Compliance" />
  <img src="https://img.shields.io/badge/Privacidade-Zero%20Persistência-blue?style=for-the-badge" alt="Zero Persistence" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <a href="https://kcal.fly.dev"><strong>🌐 Acesse a aplicação online &rarr;</strong></a>
</p>

---

## 🥗 Filosofia do Projeto: Simplicidade e Utilidade Pública

O **Kcal** não é um produto comercial, não tem planos pagos, mensalidades ou formulários de cadastro. Foi concebido como uma **ferramenta de utilidade pública** para nutricionistas, pequenos produtores, cozinhas artesanais e qualquer pessoa que precise de uma tabela nutricional oficial sem burocracia ou riscos de privacidade.

### Princípios Fundamentais:
1. **Zero Persistência no Servidor (One-Shot):** Nenhuma receita ou ingrediente que você digita é gravado no banco de dados do servidor. O cálculo é processado e mantido apenas na memória da sua sessão do navegador.
2. **Banco de Dados Estritamente Somente-Leitura:** O SQLite embarcado no servidor armazena exclusivamente as tabelas de referência científica públicas (TACO e TBCA). Ninguém na web consegue realizar operações de escrita no servidor.
3. **Exporte e Guarde Com Você:** Como a ferramenta não salva nada no servidor, você exporta o resultado final como **imagem PNG de alta resolução**, copia para a área de transferência ou imprime em PDF. Se quiser alterar a receita no futuro, baixe um backup leve em `.json` no seu próprio computador e recarregue na calculadora quando quiser.

---

## 🔬 De Onde Vêm os Dados Científicos?

Todos os valores nutricionais utilizados como base vêm de pesquisas laboratoriais oficiais brasileiras:

* **Tabela TACO (NEPA / UNICAMP):**
  A *Tabela Brasileira de Composição de Alimentos* (4ª edição revisada e ampliada, 2011), desenvolvida pelo Núcleo de Estudos e Pesquisas em Alimentação da Universidade Estadual de Campinas. Traz análises químicas detalhadas de 597 alimentos nacionais por 100 g de porção comestível (energia, carboidratos, proteínas, lipídios totais, gordura saturada, gordura trans, fibra alimentar e sódio).
* **Tabela TBCA (USP / FoRC):**
  A *Tabela Brasileira de Composição de Alimentos*, coordenada pelo Food Research Center da Universidade de São Paulo, complementando itens e preparações comuns.

---

## 🏷️ Conformidade Completa com a ANVISA (RDC 429/2020 e IN 75/2020)

* **5 Modelos Oficiais de Rotulagem (Anexos IX e XIII):**
  * **Vertical (Padrão):** Formato clássico para a maioria das embalagens.
  * **Vertical Quebrado:** Particionado em duas colunas para economia de altura.
  * **Horizontal:** Em linhas horizontais contínuas para fundos de caixas e embalagens compridas.
  * **Horizontal Quebrado:** Particionado para embalagens com restrição de altura.
  * **Linear:** Formato corrido de texto, permitido para embalagens menores que 100 cm².
* **Rotulagem Frontal (Lupa "ALTO EM"):**
  Detecção e renderização automática do selo oficial da lupa para produtos que excederem os limites legais por 100 g:
  * **Gordura Saturada:** $\ge 6\text{ g} / 100\text{ g}$
  * **Sódio:** $\ge 600\text{ mg} / 100\text{ g}$
* **Cálculo de Porção e %VD:**
  Percentuais de Valores Diários calibrados pela dieta padrão de referência de 2.000 kcal da ANVISA.
* **Declaração Legal de Ingredientes:**
  Geração automática da lista de ingredientes disposta obrigatoriamente em **ordem decrescente de peso/quantidade**, com normalização de nomes para linguagem de rotulagem.

---

## 🛠️ Stack Tecnológica

* **Linguagem & Runtime:** [Elixir 1.18](https://elixir-lang.org/) / Erlang OTP 28
* **Framework Web:** [Phoenix Framework 1.8](https://www.phoenixframework.org/)
* **Interface Reativa:** [Phoenix LiveView 1.1](https://hexdocs.pm/phoenix_live_view/)
* **Banco de Dados:** [SQLite 3](https://www.sqlite.org/) (em contêiner em modo consulta/leitura)
* **Estilização:** [Tailwind CSS v4](https://tailwindcss.com/) & [daisyUI](https://daisyui.com/) (estética brutalista, alto contraste, sem distrações)
* **Exportação Gráfica:** `html-to-image` (rasterização via SVG `<foreignObject>` para PNG 2x nítido)
* **Infraestrutura:** [Fly.io](https://fly.io) com auto-stop e inicialização sob demanda em ~1s.

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- Elixir 1.15+ e Erlang/OTP 26+

### Passos

```bash
# 1. Clone o repositório
git clone https://github.com/hjunior29/kcal.git
cd kcal

# 2. Instale dependências, inicialize o banco SQLite de referência e rode o seed TACO
mix setup

# 3. Inicie o servidor Phoenix
mix phx.server
```

Acesse [`http://localhost:4000`](http://localhost:4000) no seu navegador:
- `/` &rarr; Landing page explicativa sobre a origem dos dados e uso.
- `/calculadora` &rarr; Calculadora One-Shot com geração de rótulo ao vivo.

Para rodar os testes automatizados:
```bash
mix test
```

---

<p align="center">
  Desenvolvido com foco em transparência e código aberto por <a href="https://github.com/hjunior29">Helder Lima (@hjunior29)</a>
  <br />
  Licença MIT.
</p>
