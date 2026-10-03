defmodule KcalWeb.ComponentLive.Show do
  @moduledoc "Shows a component: ingredient breakdown + exportable Anvisa label."
  use KcalWeb, :live_view

  import KcalWeb.NutritionComponents

  alias Kcal.Nutrition

  # Selectable table models (Anexo IX) + the linear model (Anexo XIII).
  @views [
    vertical: "Vertical",
    broken: "Vertical quebrada",
    horizontal: "Horizontal",
    horizontal_broken: "Horizontal quebrada",
    linear: "Linear"
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    component = Nutrition.get_component!(id)
    report = Nutrition.component_report(component)

    {:ok,
     socket
     |> assign(:page_title, component.name)
     |> assign(:component, component)
     |> assign(:report, report)
     |> assign(:ingredients_text, ingredient_declaration(report))
     |> assign(:views, @views)
     |> assign(:view_mode, :vertical)}
  end

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) do
    # `view` is client-supplied — map explicitly to a known mode.
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header_bar>
        <:title>{@component.name}</:title>
        <:subtitle :if={@component.description}>{@component.description}</:subtitle>
        <:action>
          <.brutal_link navigate={~p"/"}>← Voltar</.brutal_link>
          <.brutal_link navigate={~p"/components/#{@component.id}/edit"} variant="solid">
            Editar
          </.brutal_link>
        </:action>
      </.header_bar>

      <%!-- 1. Front-of-pack alerts first, as on the front of a real package. --%>
      <section :if={front_warnings(@report) != [] or info_alerts(@report) != []} class="mb-10">
        <h3 class="font-bold uppercase tracking-wide text-sm border-b-2 border-black pb-1 mb-3">
          Alertas
        </h3>

        <div
          id="nutrition-export-alerts"
          phx-hook="NutritionExport"
          data-filename={"#{@component.name} - alertas"}
        >
          <.nutrition_alerts report={@report} />
          <.export_buttons />
        </div>
      </section>

      <%!-- 2. Nutrition table — pick the model, then download it. --%>
      <section class="mb-10">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3 border-b-2 border-black pb-2">
          <h3 class="font-bold uppercase tracking-wide text-sm">Tabela nutricional</h3>
          <div class="flex flex-wrap gap-1">
            <button
              :for={{mode, label} <- @views}
              type="button"
              phx-click="set_view"
              phx-value-view={mode}
              class={[
                "rounded-none border-2 border-black px-3 py-1 text-xs font-bold uppercase tracking-wide",
                @view_mode == mode && "bg-black text-white",
                @view_mode != mode && "bg-white text-black hover:bg-brand"
              ]}
            >
              {label}
            </button>
          </div>
        </div>

        <div
          id="nutrition-export-table"
          phx-hook="NutritionExport"
          data-filename={"#{@component.name} - #{@view_mode}"}
        >
          <.nutrition_facts
            :if={@view_mode == :vertical}
            report={@report}
            component={@component}
            show_warnings={false}
            show_ingredients={false}
          />
          <.nutrition_facts_broken
            :if={@view_mode == :broken}
            report={@report}
            component={@component}
          />
          <.nutrition_facts_horizontal
            :if={@view_mode == :horizontal}
            report={@report}
            component={@component}
          />
          <.nutrition_facts_horizontal_broken
            :if={@view_mode == :horizontal_broken}
            report={@report}
            component={@component}
          />
          <.nutrition_facts_linear
            :if={@view_mode == :linear}
            report={@report}
            component={@component}
            class="max-w-3xl"
          />
          <.export_buttons />
        </div>
      </section>

      <%!-- 3. Ingredients last, below the table & alerts (as on a real product):
            the plain-text declaration first, then the per-ingredient detail. --%>
      <section>
        <h3 class="font-bold uppercase tracking-wide text-sm border-b-2 border-black pb-1 mb-3">
          Ingredientes ({length(@report.result.lines)})
        </h3>

        <p
          :if={@ingredients_text != ""}
          class="mb-5 max-w-3xl border-2 border-black bg-white p-3 text-sm leading-snug text-black"
        >
          <span class="font-bold uppercase">Ingredientes:</span> {@ingredients_text}
        </p>

        <p class="text-xs opacity-60 mb-2">
          Detalhamento por ingrediente (ordem decrescente de quantidade).
        </p>

        <div
          id="nutrition-export-ingredients"
          phx-hook="NutritionExport"
          data-filename={"#{@component.name} - ingredientes"}
        >
          <table
            data-export-target
            class="w-full max-w-3xl border-collapse border-2 border-black bg-white text-black text-sm"
          >
            <thead>
              <tr class="bg-black text-white text-left">
                <th class="px-3 py-1.5 font-bold">Item</th>
                <th class="px-3 py-1.5 font-bold text-right w-24">Peso</th>
                <th class="px-3 py-1.5 font-bold text-right w-24">kcal</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={line <- Enum.sort_by(@report.result.lines, & &1.grams, :desc)}
                class="border-b border-black/30"
              >
                <td class="px-3 py-1.5">
                  {ingredient_label(line.label)}
                  <span class="text-xs opacity-60">
                    ({format_qty(line.item)})
                  </span>
                </td>
                <td class="px-3 py-1.5 text-right tabular-nums">{round(line.grams)} g</td>
                <td class="px-3 py-1.5 text-right tabular-nums">
                  {round(line.nutrients.energy_kcal)}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-black font-bold">
                <td class="px-3 py-1.5">Total</td>
                <td class="px-3 py-1.5 text-right tabular-nums">
                  {round(@report.result.total_weight_g)} g
                </td>
                <td class="px-3 py-1.5 text-right tabular-nums">
                  {round(@report.result.nutrients.energy_kcal)}
                </td>
              </tr>
            </tfoot>
          </table>
          <.export_buttons />
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp format_qty(item) do
    qty = item.quantity || 0
    abbr = (item.measure_unit && item.measure_unit.abbreviation) || "?"
    qty_str = if qty == trunc(qty), do: Integer.to_string(trunc(qty)), else: to_string(qty)
    "#{qty_str} #{abbr}"
  end
end
