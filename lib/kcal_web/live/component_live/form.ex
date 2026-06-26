defmodule KcalWeb.ComponentLive.Form do
  @moduledoc """
  The component builder: create or edit a "Componente".

  The ingredient list is held in server state (`@items`) rather than in form
  params, so the live search/add/edit interactions stay instant and we can nest
  components as easily as base foods. The Anvisa label on the right is a live
  preview recomputed on every change.
  """
  use KcalWeb, :live_view

  import KcalWeb.NutritionComponents

  alias Kcal.Nutrition
  alias Kcal.Nutrition.{Component, ComponentItem}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:measure_units, Nutrition.list_measure_units())
     |> assign(:default_unit_id, default_unit_id())
     |> assign(:search_mode, :foods)
     |> assign(:query, "")
     |> assign(:counter, 0)
     |> assign(:results, Nutrition.search_foods(""))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    component = %Component{items: []}

    socket
    |> assign(:page_title, "Novo componente")
    |> assign(:component, component)
    |> assign(:items, [])
    |> assign_form(Nutrition.change_component(component))
    |> recompute()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    component = Nutrition.get_component!(id)
    items = component.items |> Enum.map(&item_from_record/1)

    socket
    |> assign(:page_title, "Editar componente")
    |> assign(:component, component)
    |> assign(:items, items)
    |> assign(:counter, length(items))
    |> assign_form(Nutrition.change_component(component))
    |> recompute()
  end

  # --- search & nesting ----------------------------------------------------

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    # `mode` is client-controllable; map explicitly instead of String.to_existing_atom.
    mode = if mode == "components", do: :components, else: :foods

    {:noreply,
     assign(socket, search_mode: mode, results: search(mode, socket.assigns.query, socket))}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, query: q, results: search(socket.assigns.search_mode, q, socket))}
  end

  @impl true
  def handle_event("add", %{"kind" => kind, "id" => id}, socket) do
    # `kind`/`id` are client-supplied — parse defensively and no-op on bad input.
    resolved =
      case {kind, parse_int(id)} do
        {"food", n} when is_integer(n) -> {:food, Nutrition.get_food(n)}
        {"component", n} when is_integer(n) -> {:component, Nutrition.get_component(n)}
        _ -> :invalid
      end

    case resolved do
      {kind_atom, %{} = ref} ->
        counter = socket.assigns.counter + 1
        item = new_item(kind_atom, ref, counter, socket)

        {:noreply,
         socket
         |> assign(:counter, counter)
         |> assign(:items, socket.assigns.items ++ [item])
         |> recompute()}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove", %{"tid" => tid}, socket) do
    items = Enum.reject(socket.assigns.items, &(&1.temp_id == tid))
    {:noreply, socket |> assign(:items, items) |> recompute()}
  end

  @impl true
  def handle_event("update_item", %{"tid" => tid} = params, socket) do
    units = socket.assigns.measure_units

    items =
      Enum.map(socket.assigns.items, fn item ->
        if item.temp_id == tid, do: apply_item_params(item, params, units), else: item
      end)

    {:noreply, socket |> assign(:items, items) |> recompute()}
  end

  # --- scalar form ---------------------------------------------------------

  @impl true
  def handle_event("validate", %{"component" => params}, socket) do
    changeset =
      socket.assigns.component
      |> Nutrition.change_component(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign_form(changeset) |> recompute()}
  end

  @impl true
  def handle_event("save", %{"component" => params}, socket) do
    attrs = Map.put(params, "items", items_to_attrs(socket.assigns.items))
    save(socket, socket.assigns.live_action, attrs)
  end

  defp save(socket, :new, attrs) do
    case Nutrition.create_component(attrs) do
      {:ok, component} ->
        {:noreply,
         socket
         |> put_flash(:info, "Componente criado.")
         |> push_navigate(to: ~p"/components/#{component.id}")}

      {:error, changeset} ->
        {:noreply, socket |> assign_form(changeset) |> put_flash(:error, save_error(changeset))}
    end
  end

  defp save(socket, :edit, attrs) do
    case Nutrition.update_component(socket.assigns.component, attrs) do
      {:ok, component} ->
        {:noreply,
         socket
         |> put_flash(:info, "Componente atualizado.")
         |> push_navigate(to: ~p"/components/#{component.id}")}

      {:error, changeset} ->
        {:noreply, socket |> assign_form(changeset) |> put_flash(:error, save_error(changeset))}
    end
  end

  # --- render --------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header_bar>
        <:title>{@page_title}</:title>
        <:action>
          <.brutal_link navigate={~p"/"}>Cancelar</.brutal_link>
        </:action>
      </.header_bar>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-8 items-start">
        <div class="lg:col-span-3 space-y-6">
          <%!-- 1. Identity (the only real <form> — items live in server state) --%>
          <form id="component-form" phx-change="validate" phx-submit="save" class="space-y-3">
            <div>
              <label class="block text-xs font-bold uppercase tracking-wide mb-1">Nome</label>
              <input
                type="text"
                name="component[name]"
                value={Phoenix.HTML.Form.normalize_value("text", @form[:name].value)}
                placeholder="Ex.: Frango com marinado oriental"
                autocomplete="off"
                class={input_class(@form[:name])}
              />
              <p :for={msg <- field_errors(@form[:name])} class="text-xs text-red-600 mt-1">{msg}</p>
            </div>

            <div>
              <label class="block text-xs font-bold uppercase tracking-wide mb-1">Descrição</label>
              <textarea
                name="component[description]"
                rows="2"
                class={input_class(@form[:description])}
              >{Phoenix.HTML.Form.normalize_value("textarea", @form[:description].value)}</textarea>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                  Porção (g)
                </label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  name="component[serving_size_g]"
                  value={Phoenix.HTML.Form.normalize_value("number", @form[:serving_size_g].value)}
                  placeholder="ex.: 200"
                  class={input_class(@form[:serving_size_g])}
                />
              </div>
              <div>
                <label class="block text-xs font-bold uppercase tracking-wide mb-1">
                  Medida caseira
                </label>
                <input
                  type="text"
                  name="component[servings_label]"
                  value={Phoenix.HTML.Form.normalize_value("text", @form[:servings_label].value)}
                  placeholder="ex.: 1 fatia"
                  class={input_class(@form[:servings_label])}
                />
              </div>
            </div>
          </form>

          <%!-- 2. Ingredient picker --%>
          <div class="border-2 border-black">
            <div class="flex border-b-2 border-black">
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="foods"
                class={tab_class(@search_mode == :foods)}
              >
                Alimentos (TACO/TBCA)
              </button>
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="components"
                class={["border-l-2 border-black", tab_class(@search_mode == :components)]}
              >
                Componentes
              </button>
            </div>

            <div class="p-3">
              <form phx-change="search" phx-submit="search">
                <input
                  type="text"
                  name="q"
                  value={@query}
                  phx-debounce="120"
                  autocomplete="off"
                  placeholder={
                    if @search_mode == :foods,
                      do: "Digite para buscar (ex.: ovo, arroz)…",
                      else: "Buscar componente para aninhar…"
                  }
                  class="w-full rounded-none border-2 border-black bg-white px-3 py-2 focus:outline-none focus:bg-brand"
                />
              </form>

              <ul class="mt-2 max-h-72 overflow-auto divide-y divide-black/15 border-2 border-black/15">
                <li :if={@results == []} class="px-3 py-4 text-sm opacity-60 text-center">
                  Nenhum resultado.
                </li>
                <li
                  :for={r <- @results}
                  class="flex items-center justify-between gap-2 px-3 py-2 hover:bg-brand"
                >
                  <div class="min-w-0">
                    <p class="font-medium truncate">{result_name(r)}</p>
                    <p class="text-xs opacity-60 truncate">{result_meta(r, @search_mode)}</p>
                  </div>
                  <button
                    type="button"
                    phx-click="add"
                    phx-value-kind={if @search_mode == :foods, do: "food", else: "component"}
                    phx-value-id={r.id}
                    class="shrink-0 rounded-none border-2 border-black bg-white px-2 py-1 text-xs font-bold hover:bg-black hover:text-white"
                  >
                    + Adicionar
                  </button>
                </li>
              </ul>
            </div>
          </div>

          <%!-- 3. Selected items --%>
          <div>
            <h3 class="font-bold uppercase tracking-wide text-sm border-b-2 border-black pb-1 mb-2">
              Itens do componente ({length(@items)})
            </h3>

            <div
              :if={@items == []}
              class="border-2 border-dashed border-black p-6 text-center text-sm opacity-70"
            >
              Busque acima e adicione alimentos ou outros componentes.
            </div>

            <ul class="space-y-2">
              <li :for={item <- @items} class="border-2 border-black p-3">
                <div class="flex items-start justify-between gap-2">
                  <div class="min-w-0">
                    <p class="font-semibold truncate">{item.name}</p>
                    <p class="text-xs opacity-60">
                      {if item.kind == :component, do: "Componente aninhado", else: item.category}
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="remove"
                    phx-value-tid={item.temp_id}
                    class="shrink-0 rounded-none border-2 border-black px-2 py-0.5 text-xs font-bold hover:bg-red-600 hover:text-white hover:border-red-600"
                  >
                    Remover
                  </button>
                </div>

                <%!-- Inputs live in a per-item <form> so phx-change carries the
                      field values (a bare input outside a form sends none). --%>
                <form phx-change="update_item" phx-value-tid={item.temp_id} class="mt-2 space-y-2">
                  <div class="grid grid-cols-[1fr_1.4fr_auto] gap-2 items-end">
                    <div>
                      <label class="block text-[10px] font-bold uppercase opacity-70">Qtd.</label>
                      <input
                        type="number"
                        step="any"
                        min="0"
                        name="quantity"
                        value={num_value(item.quantity)}
                        phx-debounce="150"
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
                    <div class="text-right text-sm pb-1 tabular-nums w-20">
                      <span class="block text-[10px] font-bold uppercase opacity-70">= g</span>
                      {grams_label(item, @measure_units)}
                    </div>
                  </div>

                  <div :if={needs_grams?(item, @measure_units)}>
                    <label class="block text-[10px] font-bold uppercase text-red-600">
                      Gramas por unidade (obrigatório p/ esta medida)
                    </label>
                    <input
                      type="number"
                      step="any"
                      min="0"
                      name="grams_per_unit_override"
                      value={num_value(item.grams_per_unit_override)}
                      phx-debounce="150"
                      placeholder="ex.: 50 g por unidade"
                      class="w-full rounded-none border-2 border-red-600 px-2 py-1 text-sm focus:outline-none focus:bg-brand"
                    />
                  </div>
                </form>
              </li>
            </ul>
          </div>

          <%!-- Save lives at the bottom, after the component is fully built.
                `form="component-form"` keeps it tied to the identity form even
                though it sits outside it. --%>
          <div class="border-t-2 border-black pt-4">
            <button
              type="submit"
              form="component-form"
              class="w-full rounded-none border-2 border-black bg-brand text-black px-4 py-3 font-bold uppercase tracking-wide hover:bg-black hover:text-white sm:w-auto"
            >
              Salvar componente
            </button>
          </div>
        </div>

        <%!-- live Anvisa preview --%>
        <div class="lg:col-span-2 lg:sticky lg:top-4 space-y-2">
          <h3 class="font-bold uppercase tracking-wide text-sm">Pré-visualização</h3>
          <.nutrition_facts report={@report} component={@preview_component} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- working-item helpers ------------------------------------------------

  defp new_item(:food, food, counter, _socket) do
    %{
      temp_id: "new-#{counter}",
      kind: :food,
      ref_id: food.id,
      ref: food,
      name: food.name,
      category: food.category,
      measure_unit_id: default_unit_id(),
      quantity: 100.0,
      grams_per_unit_override: nil
    }
  end

  defp new_item(:component, component, counter, _socket) do
    %{
      temp_id: "new-#{counter}",
      kind: :component,
      ref_id: component.id,
      ref: component,
      name: component.name,
      category: nil,
      measure_unit_id: default_unit_id(),
      quantity: 100.0,
      grams_per_unit_override: nil
    }
  end

  defp item_from_record(%ComponentItem{} = it) do
    {kind, ref, name, category} =
      if it.food_id,
        do: {:food, it.food, it.food.name, it.food.category},
        else: {:component, it.child_component, it.child_component.name, nil}

    %{
      temp_id: "it-#{it.id}",
      kind: kind,
      ref_id: it.food_id || it.child_component_id,
      ref: ref,
      name: name,
      category: category,
      measure_unit_id: it.measure_unit_id,
      quantity: it.quantity,
      grams_per_unit_override: it.grams_per_unit_override
    }
  end

  # Apply a per-item form change. `phx-change` sends every named field in the
  # form on each edit, so we read them all (some may be absent, e.g. the
  # override input only renders for count units).
  defp apply_item_params(item, params, units) do
    measure_unit_id = parse_int(params["measure_unit_id"]) || item.measure_unit_id
    unit = Enum.find(units, &(&1.id == measure_unit_id))

    override =
      cond do
        # A unit with a fixed gram factor (g, ml, colher, xícara…) ignores any
        # per-unit override — clear a stale one left over from "Unidade".
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

  defp items_to_attrs(items) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {it, idx} ->
      base = %{
        "measure_unit_id" => it.measure_unit_id,
        "quantity" => it.quantity,
        "grams_per_unit_override" => it.grams_per_unit_override,
        "position" => idx
      }

      # Keep the persisted id on edit so cast_assoc updates in place rather than
      # deleting and re-inserting every line. New items ("new-*") stay id-less.
      base =
        case it.temp_id do
          "it-" <> id -> Map.put(base, "id", id)
          _ -> base
        end

      case it.kind do
        :food -> Map.put(base, "food_id", it.ref_id)
        :component -> Map.put(base, "child_component_id", it.ref_id)
      end
    end)
  end

  defp build_component_items(items, units) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {it, idx} ->
      unit = Enum.find(units, &(&1.id == it.measure_unit_id))

      base = %ComponentItem{
        position: idx,
        quantity: it.quantity,
        grams_per_unit_override: it.grams_per_unit_override,
        measure_unit_id: it.measure_unit_id,
        measure_unit: unit
      }

      case it.kind do
        :food -> %{base | food_id: it.ref_id, food: it.ref}
        :component -> %{base | child_component_id: it.ref_id, child_component: it.ref}
      end
    end)
  end

  # --- preview / recompute -------------------------------------------------

  defp recompute(socket) do
    preview =
      socket.assigns.form.source
      |> Ecto.Changeset.apply_changes()
      |> Map.put(
        :items,
        build_component_items(socket.assigns.items, socket.assigns.measure_units)
      )

    socket
    |> assign(:preview_component, preview)
    |> assign(:report, Nutrition.report_for(preview))
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset),
    do: assign(socket, :form, to_form(changeset))

  # --- view helpers --------------------------------------------------------

  defp search(:foods, q, _socket), do: Nutrition.search_foods(q)

  defp search(:components, q, socket),
    do: Nutrition.search_components(q, socket.assigns.component.id)

  defp result_name(r), do: r.name

  defp result_meta(%{energy_kcal: kcal} = f, :foods) do
    cat = f.category || "—"
    "#{cat} · #{round(kcal)} kcal/100g · #{f.source}"
  end

  defp result_meta(_component, :components), do: "Componente salvo"

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

  defp input_class(field) do
    [
      "w-full rounded-none border-2 bg-white px-3 py-2 focus:outline-none focus:bg-brand",
      if(field.errors == [], do: "border-black", else: "border-red-600")
    ]
  end

  defp tab_class(active?) do
    [
      "flex-1 px-3 py-2 text-sm font-bold uppercase tracking-wide",
      if(active?, do: "bg-black text-white", else: "bg-white hover:bg-brand")
    ]
  end

  defp field_errors(field) do
    Enum.map(field.errors, fn {msg, opts} ->
      KcalWeb.CoreComponents.translate_error({msg, opts})
    end)
  end

  defp save_error(changeset) do
    case changeset.errors[:items] do
      {msg, _} -> msg
      _ -> "Verifique os campos destacados."
    end
  end

  defp default_unit_id do
    case Kcal.Nutrition.default_measure_unit() do
      nil -> nil
      unit -> unit.id
    end
  end

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
end
