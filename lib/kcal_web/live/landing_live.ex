defmodule KcalWeb.LandingLive do
  @moduledoc """
  Public landing page explaining the tool's scientific origin (TACO/TBCA),
  one-shot privacy philosophy, and how to use it without commercial bias.
  """
  use KcalWeb, :live_view

  alias Kcal.Nutrition

  @impl true
  def mount(_params, _session, socket) do
    total_foods = 600
    sample_foods = Nutrition.search_foods("", 6)

    {:ok,
     socket
     |> assign(:page_title, "Início")
     |> assign(:total_foods, total_foods)
     |> assign(:sample_foods, sample_foods)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-16 text-black">
        <%!-- 1. Hero Section --%>
        <section class="border-4 border-black bg-white p-6 sm:p-10 text-black">
          <div class="inline-block border-2 border-black bg-brand px-3 py-1 text-xs font-bold uppercase tracking-wider mb-4 text-black">
            Ferramenta Aberta &amp; Gratuita · Sem Cadastro · 100% Privada
          </div>

          <h1 class="text-3xl sm:text-5xl font-extrabold uppercase tracking-tight leading-none mb-4 text-black">
            Rotulagem Nutricional Anvisa<br />
            <span class="bg-black text-white px-2 py-0.5">Transparente &amp; One-Shot</span>
          </h1>

          <p class="max-w-2xl text-base sm:text-lg leading-relaxed mb-8 text-black opacity-90">
            Calcule a informação nutricional oficial para receitas, refeições ou produtos
            com dados laboratoriais da <strong class="text-black font-extrabold">Tabela TACO (UNICAMP)</strong> e <strong class="text-black font-extrabold">TBCA (USP)</strong>.
            Zero armazenamento de dados: sua receita vive apenas na sua aba e você a exporta em alta resolução.
          </p>

          <div class="flex flex-wrap items-center gap-4">
            <.link
              navigate={~p"/calculadora"}
              class="inline-block border-2 border-black bg-brand px-6 py-3.5 text-base font-bold uppercase tracking-wider text-black hover:bg-black hover:text-white transition-colors"
            >
              Abrir Calculadora One-Shot <.icon name="hero-arrow-right" class="size-4 inline-block ml-1" />
            </.link>

            <a
              href="#dados"
              class="inline-block border-2 border-black bg-white px-5 py-3.5 text-base font-bold uppercase tracking-wider text-black hover:bg-brand transition-colors"
            >
              Origem dos Dados <.icon name="hero-arrow-down" class="size-4 inline-block ml-1" />
            </a>
          </div>

          <div class="mt-8 pt-6 border-t-2 border-black/20 grid grid-cols-2 sm:grid-cols-4 gap-4 text-xs font-bold uppercase text-black">
            <div>
              <span class="block text-2xl font-extrabold tabular-nums text-black">{@total_foods}+</span>
              <span class="text-black opacity-70">Alimentos Laboratoriais</span>
            </div>
            <div>
              <span class="block text-2xl font-extrabold tabular-nums text-black">5</span>
              <span class="text-black opacity-70">Modelos Oficiais Anvisa</span>
            </div>
            <div>
              <span class="block text-2xl font-extrabold tabular-nums text-black">0%</span>
              <span class="text-black opacity-70">Persistência em Servidor</span>
            </div>
            <div>
              <span class="block text-2xl font-extrabold tabular-nums text-black">R$ 0</span>
              <span class="text-black opacity-70">Livre de Cobrança e Planos</span>
            </div>
          </div>
        </section>

        <%!-- 2. The One-Shot Philosophy --%>
        <section class="space-y-6 text-black">
          <div class="border-b-2 border-black pb-2">
            <h2 class="text-xl sm:text-2xl font-bold uppercase tracking-tight text-black">
              A Filosofia One-Shot: Uma Calculadora, Não um SaaS
            </h2>
            <p class="text-sm text-black opacity-75 mt-1">
              Por que decidimos não salvar nada no banco de dados.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="border-2 border-black bg-white p-5 flex flex-col justify-between text-black">
              <div>
                <div class="w-8 h-8 border-2 border-black bg-brand font-black flex items-center justify-center mb-3 text-black">
                  1
                </div>
                <h3 class="font-bold uppercase tracking-wide text-base mb-2 text-black">
                  Privacidade Absoluta
                </h3>
                <p class="text-sm text-black opacity-80 leading-relaxed">
                  Sem formulários de login, sem cadastros, sem senhas e sem cookies de rastreamento.
                  Nenhuma receita criada por você passa para o disco do servidor.
                </p>
              </div>
              <p class="mt-4 text-xs font-mono font-bold text-black opacity-60">ZERO TRACKING</p>
            </div>

            <div class="border-2 border-black bg-white p-5 flex flex-col justify-between text-black">
              <div>
                <div class="w-8 h-8 border-2 border-black bg-brand font-black flex items-center justify-center mb-3 text-black">
                  2
                </div>
                <h3 class="font-bold uppercase tracking-wide text-base mb-2 text-black">
                  Cálculo &amp; Exportação
                </h3>
                <p class="text-sm text-black opacity-80 leading-relaxed">
                  Adicione os ingredientes, defina a porção e veja a tabela nutricional Anvisa ser gerada
                  na hora. Exporte o rótulo em PNG de alta resolução (2x) ou copie direto para colar onde precisar.
                </p>
              </div>
              <p class="mt-4 text-xs font-mono font-bold text-black opacity-60">PNG / CLIPBOARD</p>
            </div>

            <div class="border-2 border-black bg-white p-5 flex flex-col justify-between text-black">
              <div>
                <div class="w-8 h-8 border-2 border-black bg-brand font-black flex items-center justify-center mb-3 text-black">
                  3
                </div>
                <h3 class="font-bold uppercase tracking-wide text-base mb-2 text-black">
                  Backup Local em JSON
                </h3>
                <p class="text-sm text-black opacity-80 leading-relaxed">
                  Quer guardar sua receita para alterar depois? Baixe o arquivo <code>.json</code> no seu
                  próprio computador e recarregue na calculadora quando precisar.
                </p>
              </div>
              <p class="mt-4 text-xs font-mono font-bold text-black opacity-60">SEUS DADOS COM VOCÊ</p>
            </div>
          </div>
        </section>

        <%!-- 3. Scientific Data Sources --%>
        <section id="dados" class="space-y-6 scroll-mt-6 text-black">
          <div class="border-b-2 border-black pb-2">
            <h2 class="text-xl sm:text-2xl font-bold uppercase tracking-tight text-black">
              De Onde Vêm os Dados Nutricionais?
            </h2>
            <p class="text-sm text-black opacity-75 mt-1">
              Rigor científico: o banco de dados do servidor é estritamente de consulta a tabelas públicas e validadas.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="border-2 border-black bg-white p-6 text-black flex flex-col justify-between">
              <div>
                <div class="flex items-center justify-between mb-3 border-b-2 border-black/15 pb-2">
                  <h3 class="font-extrabold uppercase text-lg text-black">Tabela TACO (NEPA / UNICAMP)</h3>
                  <span class="border border-black px-2 py-0.5 text-xs font-bold bg-brand text-black">597 alimentos</span>
                </div>
                <p class="text-sm text-black opacity-85 leading-relaxed mb-4">
                  A <strong>Tabela Brasileira de Composição de Alimentos (TACO)</strong>, em sua 4ª edição revisada e
                  ampliada (2011), foi desenvolvida pelo Núcleo de Estudos e Pesquisas em Alimentação da Universidade
                  Estadual de Campinas (NEPA/UNICAMP).
                </p>
                <ul class="text-xs space-y-1.5 text-black opacity-80 list-disc list-inside">
                  <li>Análises físico-químicas de alimentos da biodiversidade brasileira;</li>
                  <li>Valores laboratoriais expressos por 100 g de porção comestível;</li>
                  <li>Perfil completo de macronutrientes, fibra alimentar, sódio e ácidos graxos saturados e trans.</li>
                </ul>
              </div>

              <div class="mt-5 pt-3 border-t border-black/15 flex flex-wrap gap-3 text-xs">
                <a
                  href="https://www.nepa.unicamp.br/taco/tabela.php"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-bold underline hover:opacity-75 inline-flex items-center gap-1 text-black"
                >
                  <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
                  Portal Oficial TACO (UNICAMP)
                </a>
                <a
                  href="https://www.cfn.org.br/wp-content/uploads/2017/03/taco_4_edicao_ampliada_e_revisada.pdf"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-bold underline hover:opacity-75 inline-flex items-center gap-1 text-black"
                >
                  <.icon name="hero-document-text" class="size-3.5" />
                  Documento Oficial PDF (4ª Edição)
                </a>
              </div>
            </div>

            <div class="border-2 border-black bg-white p-6 text-black flex flex-col justify-between">
              <div>
                <div class="flex items-center justify-between mb-3 border-b-2 border-black/15 pb-2">
                  <h3 class="font-extrabold uppercase text-lg text-black">Tabela TBCA (USP / FoRC)</h3>
                  <span class="border border-black px-2 py-0.5 text-xs font-bold bg-white text-black">Suplemento curado</span>
                </div>
                <p class="text-sm text-black opacity-85 leading-relaxed mb-4">
                  A <strong>Tabela Brasileira de Composição de Alimentos (TBCA)</strong>, coordenada pelo Food Research Center
                  (FoRC) da Universidade de São Paulo (USP), complementa nossa base para produtos e preparados
                  de consumo comum ausentes na TACO.
                </p>
                <ul class="text-xs space-y-1.5 text-black opacity-80 list-disc list-inside">
                  <li>Alimentos industrializados e derivados frequentes da rotina alimentar;</li>
                  <li>Critérios de harmonização e padronização com as normas vigentes;</li>
                  <li>Validação nutricional referenciada por instituições científicas nacionais.</li>
                </ul>
              </div>

              <div class="mt-5 pt-3 border-t border-black/15 flex flex-wrap gap-3 text-xs">
                <a
                  href="https://www.tbca.net.br/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-bold underline hover:opacity-75 inline-flex items-center gap-1 text-black"
                >
                  <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
                  Portal Oficial TBCA (USP/FoRC)
                </a>
                <a
                  href="https://forc.webhostusp.sti.usp.br/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-bold underline hover:opacity-75 inline-flex items-center gap-1 text-black"
                >
                  <.icon name="hero-academic-cap" class="size-3.5" />
                  Food Research Center (FoRC/USP)
                </a>
              </div>
            </div>
          </div>

          <div class="border-2 border-black bg-brand p-4 text-xs leading-relaxed text-black">
            <strong>Garantia de Leitura Apenas:</strong> O servidor hospeda a base SQLite de referência exclusivamente em
            modo de leitura para alimentar a busca de alimentos. Nenhuma operação de escrita por usuários é permitida na aplicação.
          </div>
        </section>

        <%!-- 4. Regulatory Conformity (ANVISA) --%>
        <section class="space-y-6 text-black">
          <div class="border-b-2 border-black pb-2">
            <h2 class="text-xl sm:text-2xl font-bold uppercase tracking-tight text-black">
              Padrão Regulatório Oficial ANVISA
            </h2>
            <p class="text-sm text-black opacity-75 mt-1">
              Fidelidade visual e técnica à RDC nº 429/2020 e Instrução Normativa nº 75/2020.
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="border-2 border-black p-4 bg-white text-black">
              <h4 class="font-bold uppercase text-xs mb-1 text-black">5 Modelos Gráficos</h4>
              <p class="text-xs text-black opacity-75">
                Vertical (padrão), Vertical Quebrado, Horizontal, Horizontal Quebrado e Linear para embalagens compactas.
              </p>
            </div>

            <div class="border-2 border-black p-4 bg-white text-black">
              <h4 class="font-bold uppercase text-xs mb-1 text-black">Exportação em Alta Resolução</h4>
              <p class="text-xs text-black opacity-75">
                Gere imagens em PNG 2x nítidas prontas para impressão e rótulos, ou copie direto para a área de transferência.
              </p>
            </div>

            <div class="border-2 border-black p-4 bg-white text-black">
              <h4 class="font-bold uppercase text-xs mb-1 text-black">Cálculo de %VD</h4>
              <p class="text-xs text-black opacity-75">
                Percentuais de Valores Diários calibrados pela dieta padrão de referência de 2.000 kcal da ANVISA.
              </p>
            </div>

            <div class="border-2 border-black p-4 bg-white text-black">
              <h4 class="font-bold uppercase text-xs mb-1 text-black">Lista de Ingredientes</h4>
              <p class="text-xs text-black opacity-75">
                Declaração textual gerada automaticamente na ordem decrescente obrigatória de peso dos insumos.
              </p>
            </div>
          </div>
        </section>

        <%!-- 5. Bottom Call to Action --%>
        <section class="border-4 border-black bg-brand p-8 text-center sm:p-12 text-black">
          <h2 class="text-2xl sm:text-4xl font-extrabold uppercase tracking-tight mb-3 text-black">
            Pronto para montar sua tabela nutricional?
          </h2>
          <p class="text-sm sm:text-base text-black opacity-90 max-w-xl mx-auto mb-6">
            Basta abrir a calculadora, digitar o nome da sua receita, buscar os ingredientes e
            exportar sua tabela Anvisa pronta para imprimir ou colar no seu rótulo.
          </p>
          <.link
            navigate={~p"/calculadora"}
            class="inline-block border-2 border-black bg-black text-white px-8 py-4 text-base font-bold uppercase tracking-wider hover:bg-white hover:text-black transition-colors"
          >
            Abrir Calculadora One-Shot Agora <.icon name="hero-arrow-right" class="size-5 inline-block ml-1" />
          </.link>
        </section>

        <%!-- Footer Note --%>
        <footer class="border-t-2 border-black pt-6 pb-12 flex flex-col sm:flex-row items-center justify-between text-xs text-black opacity-75 gap-4">
          <p>
            <strong>kcal</strong> · Projeto de código aberto para utilidade pública sob licença MIT.
          </p>
          <p>
            Dados oficiais: TACO/UNICAMP e TBCA/USP. Não substitui ensaios laboratoriais para fins industriais mandatórios.
          </p>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end
