defmodule KcalWeb.ComponentLive.Show do
  @moduledoc "Shows a component: ingredient breakdown + exportable Anvisa label."
  use KcalWeb, :live_view

  import KcalWeb.NutritionComponents

  alias Kcal.Nutrition

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    component = Nutrition.get_component!(id)
    report = Nutrition.component_report(component)

    {:ok,
     socket
     |> assign(:page_title, component.name)
     |> assign(:component, component)
     |> assign(:report, report)}
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

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start">
        <section>
          <h3 class="font-bold uppercase tracking-wide text-sm border-b-2 border-black pb-1 mb-3">
            Ingredientes ({length(@report.result.lines)})
          </h3>

          <table class="w-full border-collapse border-2 border-black text-sm">
            <thead>
              <tr class="bg-black text-white text-left">
                <th class="px-3 py-1.5 font-bold">Item</th>
                <th class="px-3 py-1.5 font-bold text-right w-24">Peso</th>
                <th class="px-3 py-1.5 font-bold text-right w-24">kcal</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={line <- @report.result.lines} class="border-b border-black/30">
                <td class="px-3 py-1.5">
                  {line.label}
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
        </section>

        <section>
          <h3 class="font-bold uppercase tracking-wide text-sm border-b-2 border-black pb-1 mb-3">
            Tabela nutricional
          </h3>

          <div id="nutrition-export" phx-hook="NutritionExport" data-filename={@component.name}>
            <.nutrition_facts report={@report} component={@component} />

            <div class="mt-3 flex flex-wrap items-center gap-2">
              <button
                type="button"
                data-export="download"
                class="rounded-none border-2 border-black bg-black text-white px-3 py-2 text-sm font-bold hover:bg-white hover:text-black"
              >
                Baixar imagem
              </button>
              <button
                type="button"
                data-export="copy"
                class="rounded-none border-2 border-black bg-white px-3 py-2 text-sm font-bold hover:bg-black hover:text-white"
              >
                Copiar imagem
              </button>
              <span data-export-status class="text-xs opacity-70" aria-live="polite"></span>
            </div>
          </div>
        </section>
      </div>
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
