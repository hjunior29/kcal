defmodule KcalWeb.CalculatorLive do
  @moduledoc """
  The One-Shot Nutrition Calculator:
  Build a recipe in-memory, view real-time ANVISA compliant nutrition facts,
  and export the result. Zero database writes.
  """
  use KcalWeb, :live_view

  import KcalWeb.NutritionComponents

  alias Kcal.Nutrition
  alias Kcal.Nutrition.Food

  @views [
    vertical: "Vertical",
    broken: "Vertical quebrada",
    horizontal: "Horizontal",
    horizontal_broken: "Horizontal quebrada",
    linear: "Linear"
  ]

  @impl true
  def mount(_params, _session, socket) do
    units = Nutrition.list_measure_units()
    default_unit = Nutrition.default_measure_unit()
    default_unit_id = (default_unit && default_unit.id) || 1

    initial_recipe = %{
      name: "Minha Receita",
      description: "",
      serving_size_g: 100.0,
      servings_label: "1 porção"
    }

    {:ok,
     socket
     |> assign(:page_title, "Calculadora One-Shot")
     |> assign(:measure_units, units)
     |> assign(:default_unit_id, default_unit_id)
     |> assign(:query, "")
     |> assign(:results, Nutrition.search_foods(""))
     |> assign(:recipe, initial_recipe)
     |> assign(:items, [])
     |> assign(:counter, 0)
     |> assign(:views, @views)
     |> assign(:view_mode, :vertical)
     |> recompute()}
  end

  # --- Search & Adding items ------------------------------------------------

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, query: q, results: Nutrition.search_foods(q))}
  end

  @impl true
  def handle_event("add_food", %{"id" => id}, socket) do
    case parse_int(id) do
      n when is_integer(n) ->
        case Nutrition.get_food(n) do
          %Food{} = food ->
            counter = socket.assigns.counter + 1
            item = new_item(food, counter, socket.assigns.default_unit_id)

            {:noreply,
             socket
             |> assign(:counter, counter)
             |> assign(:items, socket.assigns.items ++ [item])
             |> recompute()}

          _ ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_item", %{"tid" => tid}, socket) do
    items = Enum.reject(socket.assigns.items, &(&1.temp_id == tid))
    {:noreply, socket |> assign(:items, items) |> recompute()}
  end

  @impl true
  def handle_event("update_item", %{"tid" => tid} = params, socket) do
    units = socket.assigns.measure_units

    items =
      Enum.map(socket.assigns.items, fn item ->
        if item.temp_id == tid do
          apply_item_params(item, params, units)
        else
          item
        end
      end)

    {:noreply, socket |> assign(:items, items) |> recompute()}
  end

  # --- Recipe metadata changes ----------------------------------------------

  @impl true
  def handle_event("update_recipe", %{"recipe" => params}, socket) do
    recipe = %{
      name: Map.get(params, "name", socket.assigns.recipe.name),
      description: Map.get(params, "description", socket.assigns.recipe.description),
      serving_size_g: parse_float(params["serving_size_g"]),
      servings_label: Map.get(params, "servings_label", socket.assigns.recipe.servings_label)
    }

    {:noreply, socket |> assign(:recipe, recipe) |> recompute()}
  end

  # --- View Mode ------------------------------------------------------------

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) do
    mode =
      case view do
        "broken" -> :broken
        "horizontal" -> :horizontal
        "horizontal_broken" -> :horizontal_broken
        "linear" -> :linear
        _ -> :vertical
      end

    {:noreply, assign(socket, :view_mode, mode)}
  end

  # --- Utility actions (Sample, Clear, Print, Export/Import JSON) -----------

  @impl true
  def handle_event("clear_recipe", _params, socket) do
    {:noreply,
     socket
     |> assign(:items, [])
     |> assign(:recipe, %{
       name: "Nova Receita",
       description: "",
       serving_size_g: 100.0,
       servings_label: "1 porção"
     })
     |> recompute()}
  end

  @impl true
  def handle_event("load_sample", _params, socket) do
    # Load 3 sample foods from TACO
    chicken = Nutrition.search_foods("Frango, peito, sem pele, grelhado", 1) |> List.first()
    rice = Nutrition.search_foods("Arroz, integral, cozido", 1) |> List.first()
    olive_oil = Nutrition.search_foods("Azeite, de oliva, extra virgem", 1) |> List.first()
    units = socket.assigns.measure_units
    g_unit = Enum.find(units, &(&1.abbreviation == "g")) || hd(units)
    tbsp_unit = Enum.find(units, &(&1.abbreviation == "cds")) || g_unit

    items =
      [
        chicken &&
          %{
            temp_id: "sample-1",
            food_id: chicken.id,
            food: chicken,
            name: chicken.name,
            category: chicken.category,
            measure_unit_id: g_unit.id,
            quantity: 150.0,
            grams_per_unit_override: nil
          },
        rice &&
          %{
            temp_id: "sample-2",
            food_id: rice.id,
            food: rice,
            name: rice.name,
            category: rice.category,
            measure_unit_id: g_unit.id,
            quantity: 120.0,
            grams_per_unit_override: nil
          },
        olive_oil &&
          %{
            temp_id: "sample-3",
            food_id: olive_oil.id,
            food: olive_oil,
            name: olive_oil.name,
            category: olive_oil.category,
            measure_unit_id: tbsp_unit.id,
            quantity: 1.0,
            grams_per_unit_override: nil
          }
      ]
      |> Enum.reject(&is_nil/1)

    recipe = %{
      name: "Marmita Saudável de Frango",
      description: "Peito de frango grelhado com arroz integral e azeite",
      serving_size_g: 285.0,
      servings_label: "1 marmita"
    }

    {:noreply,
     socket
     |> assign(:recipe, recipe)
     |> assign(:items, items)
     |> assign(:counter, 3)
     |> recompute()}
  end

  @impl true
  def handle_event("export_json", _params, socket) do
    data = %{
      "version" => "1.0",
      "recipe" => socket.assigns.recipe,
      "items" =>
        Enum.map(socket.assigns.items, fn item ->
          %{
            "food_id" => item.food_id,
            "food_name" => item.name,
            "measure_unit_id" => item.measure_unit_id,
            "quantity" => item.quantity,
            "grams_per_unit_override" => item.grams_per_unit_override
          }
        end)
    }

    json_content = Jason.encode!(data, pretty: true)
    filename = "#{sanitize_filename(socket.assigns.recipe.name)}.json"

    {:noreply, push_event(socket, "download-json", %{content: json_content, filename: filename})}
  end

  @impl true
  def handle_event("import_recipe", %{"recipe" => recipe_data, "items" => items_data}, socket) do
    default_unit_id = socket.assigns.default_unit_id

    imported_recipe = %{
      name: recipe_data["name"] || "Receita Importada",
      description: recipe_data["description"] || "",
      serving_size_g: parse_float(recipe_data["serving_size_g"]) || 100.0,
      servings_label: recipe_data["servings_label"] || "1 porção"
    }

    imported_items =
      items_data
      |> Enum.with_index(1)
      |> Enum.map(fn {item_map, idx} ->
        food =
          case item_map["food_id"] do
            id when is_integer(id) -> Nutrition.get_food(id)
            _ -> nil
          end

        # If food_id didn't match, attempt search by food_name
        food =
          food ||
            (item_map["food_name"] &&
               Nutrition.search_foods(item_map["food_name"], 1) |> List.first())

        if food do
          unit_id = parse_int(item_map["measure_unit_id"]) || default_unit_id

          %{
            temp_id: "imported-#{idx}",
            food_id: food.id,
            food: food,
            name: food.name,
            category: food.category,
            measure_unit_id: unit_id,
            quantity: parse_float(item_map["quantity"]) || 100.0,
            grams_per_unit_override: parse_float(item_map["grams_per_unit_override"])
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:noreply,
     socket
     |> assign(:recipe, imported_recipe)
     |> assign(:items, imported_items)
     |> assign(:counter, length(imported_items))
     |> put_flash(:info, "Receita carregada com sucesso!")
     |> recompute()}
  end

  def handle_event("import_recipe", _invalid, socket) do
    {:noreply, put_flash(socket, :error, "Formato de arquivo JSON inválido.")}
  end

  @impl true
  def handle_event("trigger_print", _params, socket) do
    {:noreply, push_event(socket, "trigger-print", %{})}
  end

  # --- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- One-shot notice banner --%>
      <div class="mb-6 border-2 border-black bg-brand/50 p-3.5 text-xs sm:text-sm font-medium flex items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <span class="text-base font-bold">⚠️</span>
          <span>
            <strong>Modo One-Shot (100% Privado):</strong>
            Esta aplicação não salva nada no servidor. Os dados existem apenas nesta aba.
            <strong>Exporte sua tabela</strong> antes de sair.
          </span>
        </div>
        <.link navigate={~p"/"} class="underline font-bold text-xs shrink-0 hover:opacity-75">
          Sobre os Dados &rarr;
        </.link>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-8 items-start">
        <%!-- Left Column: Recipe Editor (3 cols) --%>
        <div class="lg:col-span-3 space-y-6">
          <%!-- 1. Recipe Identity --%>
          <div class="border-2 border-black bg-white p-4">
            <h3 class="font-bold uppercase tracking-wide text-xs border-b-2 border-black/15 pb-2 mb-3">
              1. Identificação da Receita
            </h3>

            <form phx-change="update_recipe" class="space-y-3">
              <div>
                <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                  Nome da receita
                </label>
                <input
                  type="text"
                  name="recipe[name]"
                  value={@recipe.name}
                  placeholder="Ex.: Marmita de Frango com Arroz"
                  autocomplete="off"
                  class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-sm focus:outline-none focus:bg-brand"
                />
              </div>

              <div>
                <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                  Descrição (opcional)
                </label>
                <input
                  type="text"
                  name="recipe[description]"
                  value={@recipe.description}
                  placeholder="Ex.: Almoço fitness balanceado"
                  autocomplete="off"
                  class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-sm focus:outline-none focus:bg-brand"
                />
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                    Porção de consumo (g)
                  </label>
                  <input
                    type="number"
                    step="any"
                    min="1"
                    name="recipe[serving_size_g]"
                    value={num_value(@recipe.serving_size_g)}
                    placeholder="ex.: 100"
                    class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-sm focus:outline-none focus:bg-brand"
                  />
                </div>
                <div>
                  <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                    Medida caseira da porção
                  </label>
                  <input
                    type="text"
                    name="recipe[servings_label]"
                    value={@recipe.servings_label}
                    placeholder="ex.: 1 marmita, 1 fatia"
                    autocomplete="off"
                    class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-sm focus:outline-none focus:bg-brand"
                  />
                </div>
              </div>
            </form>
          </div>

          <%!-- 2. Scientific Food Search (TACO / TBCA) --%>
          <div class="border-2 border-black bg-white">
            <div class="bg-black text-white px-4 py-2 flex items-center justify-between">
              <h3 class="font-bold uppercase tracking-wide text-xs">
                2. Banco de Alimentos (TACO / TBCA)
              </h3>
              <span class="text-[10px] font-mono opacity-80">600 alimentos científicos</span>
            </div>

            <div class="p-3">
              <form phx-change="search" phx-submit="search">
                <input
                  type="text"
                  name="q"
                  value={@query}
                  phx-debounce="100"
                  autocomplete="off"
                  placeholder="Buscar alimento (ex: frango, arroz, ovo, banana, aveia, azeite)..."
                  class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-sm focus:outline-none focus:bg-brand"
                />
              </form>

              <ul class="mt-2 max-h-64 overflow-auto divide-y divide-black/15 border-2 border-black/15">
                <li :if={@results == []} class="px-3 py-4 text-xs opacity-60 text-center">
                  Nenhum alimento encontrado para "{@query}".
                </li>
                <li
                  :for={r <- @results}
                  class="flex items-center justify-between gap-2 px-3 py-2 hover:bg-brand"
                >
                  <div class="min-w-0">
                    <p class="font-medium text-xs truncate">{r.name}</p>
                    <p class="text-[10px] opacity-60 truncate">
                      {r.category || "Geral"} · {round(r.energy_kcal)} kcal/100g · {r.source}
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="add_food"
                    phx-value-id={r.id}
                    class="shrink-0 rounded-none border-2 border-black bg-white px-2.5 py-1 text-xs font-bold hover:bg-black hover:text-white transition-colors"
                  >
                    + Adicionar
                  </button>
                </li>
              </ul>
            </div>
          </div>

          <%!-- 3. Recipe Ingredients List --%>
          <div>
            <div class="flex items-center justify-between border-b-2 border-black pb-1 mb-3">
              <h3 class="font-bold uppercase tracking-wide text-xs">
                3. Ingredientes Adicionados ({length(@items)})
              </h3>

              <div class="flex items-center gap-2">
                <button
                  :if={@items == []}
                  type="button"
                  phx-click="load_sample"
                  class="border border-black bg-brand px-2 py-0.5 text-[11px] font-bold uppercase hover:bg-black hover:text-white"
                >
                  Carregar Exemplo
                </button>
                <button
                  :if={@items != []}
                  type="button"
                  phx-click="clear_recipe"
                  data-confirm="Deseja limpar todos os ingredientes desta receita?"
                  class="border border-black bg-white px-2 py-0.5 text-[11px] font-bold uppercase hover:bg-red-600 hover:text-white hover:border-red-600"
                >
                  Limpar
                </button>
              </div>
            </div>

            <div
              :if={@items == []}
              class="border-2 border-dashed border-black p-8 text-center bg-white space-y-2"
            >
              <p class="font-bold text-sm">Sua receita ainda não possui ingredientes.</p>
              <p class="text-xs opacity-70 max-w-sm mx-auto">
                Busque alimentos acima e clique em <strong>+ Adicionar</strong> ou clique em
                <strong>Carregar Exemplo</strong> para ver uma receita pré-montada.
              </p>
            </div>

            <ul class="space-y-2">
              <li :for={item <- @items} class="border-2 border-black bg-white p-3">
                <div class="flex items-start justify-between gap-2">
                  <div class="min-w-0">
                    <p class="font-semibold text-xs truncate">{item.name}</p>
                    <p class="text-[10px] opacity-60">{item.category}</p>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_item"
                    phx-value-tid={item.temp_id}
                    title="Remover este ingrediente"
                    class="shrink-0 border-2 border-black px-2 py-0.5 text-xs font-bold hover:bg-red-600 hover:text-white hover:border-red-600"
                  >
                    ×
                  </button>
                </div>

                <form phx-change="update_item" phx-value-tid={item.temp_id} class="mt-2 space-y-2">
                  <div class="grid grid-cols-[1fr_1.5fr_auto] gap-2 items-end">
                    <div>
                      <label class="block text-[10px] font-bold uppercase opacity-70">Qtd.</label>
                      <input
                        type="number"
                        step="any"
                        min="0"
                        name="quantity"
                        value={num_value(item.quantity)}
                        phx-debounce="100"
                        class="w-full rounded-none border-2 border-black px-2 py-1 text-sm focus:outline-none focus:bg-brand"
                      />
                    </div>
                    <div>
                      <label class="block text-[10px] font-bold uppercase opacity-70">Medida</label>
                      <select
                        name="measure_unit_id"
                        class="w-full rounded-none border-2 border-black px-2 py-1 text-sm bg-white focus:outline-none"
                      >
                        <option
                          :for={u <- @measure_units}
                          value={u.id}
                          selected={u.id == item.measure_unit_id}
                        >
                          {u.name} ({u.abbreviation})
                        </option>
                      </select>
                    </div>
                    <div class="text-right text-xs pb-1 tabular-nums w-20">
                      <span class="block text-[9px] font-bold uppercase opacity-70">= g</span>
                      <span class="font-bold">{grams_label(item, @measure_units)}</span>
                    </div>
                  </div>

                  <div :if={needs_grams?(item, @measure_units)}>
                    <label class="block text-[10px] font-bold uppercase text-red-600">
                      Gramas por unidade (obrigatório p/ "unidade")
                    </label>
                    <input
                      type="number"
                      step="any"
                      min="0"
                      name="grams_per_unit_override"
                      value={num_value(item.grams_per_unit_override)}
                      phx-debounce="100"
                      placeholder="ex.: 50 (peso de 1 unidade)"
                      class="w-full rounded-none border-2 border-red-600 px-2 py-1 text-xs focus:outline-none focus:bg-brand"
                    />
                  </div>
                </form>
              </li>
            </ul>
          </div>

          <%!-- 4. Recipe Portability Tools (JSON Backup & Restore) --%>
          <div class="border-2 border-black bg-white p-4 space-y-3">
            <h4 class="font-bold uppercase tracking-wide text-xs">
              Salvar / Carregar Receita (Backup Local)
            </h4>
            <p class="text-xs opacity-75">
              Como não salvamos receitas no servidor, você pode baixar um arquivo <code>.json</code> no
              seu dispositivo para reabrir esta receita a qualquer momento:
            </p>

            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                phx-click="export_json"
                disabled={@items == []}
                class="border-2 border-black bg-white px-3 py-1.5 text-xs font-bold uppercase hover:bg-brand disabled:opacity-50"
              >
                💾 Baixar JSON da Receita
              </button>

              <label class="border-2 border-black bg-white px-3 py-1.5 text-xs font-bold uppercase hover:bg-brand cursor-pointer inline-flex items-center">
                📂 Carregar JSON da Receita
                <input
                  type="file"
                  id="recipe-json-import"
                  accept=".json,application/json"
                  phx-hook="RecipeImport"
                  class="sr-only"
                />
              </label>
            </div>
          </div>
        </div>

        <%!-- Right Column: Live ANVISA Nutrition Label & Export (2 cols) --%>
        <div class="lg:col-span-2 lg:sticky lg:top-4 space-y-4">
          <div class="border-2 border-black bg-white p-3 space-y-3">
            <div class="flex items-center justify-between border-b-2 border-black/15 pb-2">
              <h3 class="font-bold uppercase tracking-wide text-xs">
                Tabela Nutricional ANVISA
              </h3>
              <span class="text-[10px] font-bold uppercase bg-brand border border-black px-1.5 py-0.5">
                RDC 429/2020
              </span>
            </div>

            <%!-- Format Selector --%>
            <div>
              <label class="block text-[10px] font-bold uppercase opacity-70 mb-1">
                Modelo Oficial
              </label>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-1">
                <button
                  :for={{mode, label} <- @views}
                  type="button"
                  phx-click="set_view"
                  phx-value-view={mode}
                  class={[
                    "rounded-none border-2 border-black px-2 py-1 text-[11px] font-bold uppercase tracking-wide",
                    @view_mode == mode && "bg-black text-white",
                    @view_mode != mode && "bg-white text-black hover:bg-brand"
                  ]}
                >
                  {label}
                </button>
              </div>
            </div>

            <%!-- Export Actions --%>
            <div class="pt-2 border-t-2 border-black/15 flex flex-wrap gap-2 items-center">
              <button
                type="button"
                data-export="download"
                title="Baixar imagem em PNG de alta resolução"
                class="flex-1 border-2 border-black bg-brand px-3 py-2 text-xs font-bold uppercase tracking-wide hover:bg-black hover:text-white transition-colors text-center"
              >
                ⬇ Baixar PNG
              </button>
              <button
                type="button"
                data-export="copy"
                title="Copiar imagem para colar no WhatsApp, Canva, etc"
                class="border-2 border-black bg-white px-3 py-2 text-xs font-bold uppercase tracking-wide hover:bg-brand transition-colors"
              >
                📋 Copiar
              </button>
              <button
                type="button"
                phx-click="trigger_print"
                title="Imprimir ou Salvar em PDF"
                class="border-2 border-black bg-white px-3 py-2 text-xs font-bold uppercase tracking-wide hover:bg-brand transition-colors"
              >
                🖨 Imprimir / PDF
              </button>
            </div>
            <p data-export-status class="text-xs font-bold text-black" aria-live="polite"></p>
          </div>

          <%!-- Rendered Table with Export Hook --%>
          <div
            id="nutrition-export-wrapper"
            phx-hook="NutritionExport"
            data-filename={"#{sanitize_filename(@recipe.name)} - tabela nutricional"}
            class="space-y-4"
          >
            <%!-- Front-of-pack alerts (if thresholds exceeded) --%>
            <div :if={front_warnings(@report) != [] or info_alerts(@report) != []}>
              <.nutrition_alerts report={@report} />
            </div>

            <%!-- Selected Table Model --%>
            <.nutrition_facts
              :if={@view_mode == :vertical}
              report={@report}
              component={@preview_component}
              show_warnings={false}
              show_ingredients={false}
            />
            <.nutrition_facts_broken
              :if={@view_mode == :broken}
              report={@report}
              component={@preview_component}
            />
            <.nutrition_facts_horizontal
              :if={@view_mode == :horizontal}
              report={@report}
              component={@preview_component}
            />
            <.nutrition_facts_horizontal_broken
              :if={@view_mode == :horizontal_broken}
              report={@report}
              component={@preview_component}
            />
            <.nutrition_facts_linear
              :if={@view_mode == :linear}
              report={@report}
              component={@preview_component}
            />
          </div>

          <%!-- Mandatory Ingredients Declaration --%>
          <div class="border-2 border-black bg-white p-3 space-y-2">
            <h4 class="font-bold uppercase tracking-wide text-xs">
              Declaração de Ingredientes
            </h4>
            <p :if={@ingredients_text != ""} class="text-xs leading-snug">
              <strong>Ingredientes:</strong> {@ingredients_text}
            </p>
            <p :if={@ingredients_text == ""} class="text-xs opacity-60">
              Adicione ingredientes para gerar a declaração em ordem decrescente de quantidade.
            </p>
          </div>

          <%!-- Per-ingredient Breakdown Table --%>
          <div :if={@report.result.lines != []} class="border-2 border-black bg-white p-3 space-y-2">
            <h4 class="font-bold uppercase tracking-wide text-xs">
              Detalhamento de Insumos
            </h4>
            <table class="w-full text-xs border-collapse">
              <thead>
                <tr class="border-b-2 border-black text-left font-bold">
                  <th class="py-1">Alimento</th>
                  <th class="py-1 text-right">Peso</th>
                  <th class="py-1 text-right">kcal</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={line <- Enum.sort_by(@report.result.lines, & &1.grams, :desc)}
                  class="border-b border-black/20"
                >
                  <td class="py-1 truncate max-w-[140px]">{line.label}</td>
                  <td class="py-1 text-right tabular-nums">{round(line.grams)} g</td>
                  <td class="py-1 text-right tabular-nums">{round(line.nutrients.energy_kcal)}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="font-bold border-t-2 border-black">
                  <td class="py-1">Total</td>
                  <td class="py-1 text-right tabular-nums">
                    {round(@report.result.total_weight_g)} g
                  </td>
                  <td class="py-1 text-right tabular-nums">
                    {round(@report.result.nutrients.energy_kcal)}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Helpers --------------------------------------------------------------

  defp new_item(food, counter, default_unit_id) do
    %{
      temp_id: "it-#{counter}",
      food_id: food.id,
      food: food,
      name: food.name,
      category: food.category,
      measure_unit_id: default_unit_id,
      quantity: 100.0,
      grams_per_unit_override: nil
    }
  end

  defp apply_item_params(item, params, units) do
    measure_unit_id = parse_int(params["measure_unit_id"]) || item.measure_unit_id
    unit = Enum.find(units, &(&1.id == measure_unit_id))

    override =
      cond do
        unit && is_number(unit.grams_per_unit) ->
          nil

        Map.has_key?(params, "grams_per_unit_override") ->
          parse_float(params["grams_per_unit_override"])

        true ->
          item.grams_per_unit_override
      end

    %{
      item
      | quantity: parse_float(params["quantity"]) || item.quantity,
        measure_unit_id: measure_unit_id,
        grams_per_unit_override: override
    }
  end

  defp recompute(socket) do
    units = socket.assigns.measure_units

    component_items =
      Enum.map(socket.assigns.items, fn it ->
        unit = Enum.find(units, &(&1.id == it.measure_unit_id))

        %{
          food_id: it.food_id,
          food: it.food,
          measure_unit_id: it.measure_unit_id,
          measure_unit: unit,
          quantity: it.quantity,
          grams_per_unit_override: it.grams_per_unit_override
        }
      end)

    preview_component = %{
      name: socket.assigns.recipe.name,
      description: socket.assigns.recipe.description,
      serving_size_g: socket.assigns.recipe.serving_size_g,
      servings_label: socket.assigns.recipe.servings_label,
      items: component_items
    }

    report = Nutrition.report_for(preview_component)

    socket
    |> assign(:preview_component, preview_component)
    |> assign(:report, report)
    |> assign(:ingredients_text, ingredient_declaration(report))
  end

  defp grams_label(item, units) do
    case line_grams(item, units) do
      nil -> "—"
      g -> "#{round(g)} g"
    end
  end

  defp line_grams(item, units) do
    unit = Enum.find(units, &(&1.id == item.measure_unit_id))
    gpu = item.grams_per_unit_override || (unit && unit.grams_per_unit)

    if is_number(gpu), do: (item.quantity || 0.0) * gpu, else: nil
  end

  defp needs_grams?(item, units) do
    unit = Enum.find(units, &(&1.id == item.measure_unit_id))
    is_nil(item.grams_per_unit_override) and (is_nil(unit) or is_nil(unit.grams_per_unit))
  end

  defp num_value(nil), do: ""
  defp num_value(n) when is_float(n) and n == trunc(n), do: Integer.to_string(trunc(n))
  defp num_value(n), do: to_string(n)

  defp parse_float(value) when is_number(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    case value |> String.trim() |> String.replace(",", ".") |> Float.parse() do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_float(_), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp sanitize_filename(name) do
    (name || "receita")
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.replace(~r/(^-|-$)/, "")
  end
end
