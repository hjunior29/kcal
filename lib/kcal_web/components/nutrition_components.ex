defmodule KcalWeb.NutritionComponents do
  @moduledoc """
  The Anvisa-style nutrition label (Tabela / Informação Nutricional).

  Renders the strict element order required by Brazilian labelling rules
  (RDC 429/2020 + IN 75/2020): Valor energético, Carboidratos, Proteínas,
  Gorduras totais, Gorduras saturadas, Gorduras trans, Fibra alimentar, Sódio.

  Two value columns are shown — per 100 g and per portion — plus a %VD column
  (Percentual de Valores Diários) computed against the official reference
  values. The markup is deliberately brutalist: square corners, heavy black
  rules, no shadows. The whole label sits inside a `data-export-target` element
  so the client-side `NutritionExport` hook can rasterize it to PNG.
  """
  use Phoenix.Component

  alias Kcal.Nutrition.{Calculator, Nutrients}

  # Official daily reference values (Valores Diários — IN 75/2020).
  # `nil` means "no reference value established" (e.g. gorduras trans).
  @reference_values %{
    energy_kcal: 2000.0,
    carbohydrate_g: 300.0,
    protein_g: 50.0,
    total_fat_g: 65.0,
    saturated_fat_g: 20.0,
    trans_fat_g: nil,
    fiber_g: 25.0,
    sodium_mg: 2000.0
  }

  # Row spec in the mandatory Anvisa order. `unit` drives formatting.
  @rows [
    %{key: :energy_kcal, label: "Valor energético", unit: :energy, emphasis: true},
    %{key: :carbohydrate_g, label: "Carboidratos", unit: :g, emphasis: false},
    %{key: :protein_g, label: "Proteínas", unit: :g, emphasis: false},
    %{key: :total_fat_g, label: "Gorduras totais", unit: :g, emphasis: false},
    %{
      key: :saturated_fat_g,
      label: "Gorduras saturadas",
      unit: :g,
      emphasis: false,
      indent: true
    },
    %{key: :trans_fat_g, label: "Gorduras trans", unit: :g, emphasis: false, indent: true},
    %{key: :fiber_g, label: "Fibra alimentar", unit: :g, emphasis: false},
    %{key: :sodium_mg, label: "Sódio", unit: :mg, emphasis: false}
  ]

  @doc """
  Renders the nutrition label for a component report.

    * `:report` — the map returned by `Kcal.Nutrition.component_report/1`
    * `:component` — the `%Component{}` (used for name + serving metadata)
    * `:title` — optional override for the box title
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :title, :string, default: "INFORMAÇÃO NUTRICIONAL"
  attr :class, :string, default: nil

  def nutrition_facts(assigns) do
    portion_g = portion_grams(assigns.component, assigns.report)

    per_100g = assigns.report.per_100g
    per_portion = Calculator.per_serving(assigns.report.result, portion_g) || Nutrients.zero()

    assigns =
      assigns
      |> assign(:rows, @rows)
      |> assign(:portion_g, portion_g)
      |> assign(:per_100g, per_100g)
      |> assign(:per_portion, per_portion)
      |> assign(:servings_label, assigns.component.servings_label)

    ~H"""
    <div
      data-export-target
      class={[
        "bg-white text-black border-[3px] border-black font-sans w-full max-w-md",
        @class
      ]}
    >
      <div class="border-b-[3px] border-black px-3 py-2">
        <h2 class="text-2xl font-extrabold tracking-tight uppercase leading-none">{@title}</h2>
        <p :if={@component.name} class="text-sm font-semibold mt-1">{@component.name}</p>
      </div>

      <div class="px-3 py-1.5 text-[13px] leading-tight border-b-[3px] border-black">
        <div class="flex justify-between">
          <span>Porção</span>
          <span class="font-bold">
            {format_number(@portion_g, 0)} g{if @servings_label, do: " (#{@servings_label})", else: ""}
          </span>
        </div>
        <div class="flex justify-between">
          <span>Peso total do preparo</span>
          <span class="font-bold">{format_number(@report.result.total_weight_g, 0)} g</span>
        </div>
      </div>

      <table class="w-full border-collapse text-[13px]">
        <thead>
          <tr class="border-b-2 border-black">
            <th class="text-left font-bold px-3 py-1"></th>
            <th class="text-right font-bold px-2 py-1 w-[22%]">100 g</th>
            <th class="text-right font-bold px-2 py-1 w-[26%]">
              Porção<br />{format_number(@portion_g, 0)} g
            </th>
            <th class="text-right font-bold px-3 py-1 w-[16%]">%VD*</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={row <- @rows}
            class={[
              "border-b border-black/60",
              row.emphasis && "font-bold border-b-2 border-black"
            ]}
          >
            <td class={["px-3 py-1", row[:indent] && "pl-6 font-normal"]}>{row.label}</td>
            <td class="text-right px-2 py-1 tabular-nums">
              {cell(Map.fetch!(@per_100g, row.key), row.unit)}
            </td>
            <td class="text-right px-2 py-1 tabular-nums font-semibold">
              {cell(Map.fetch!(@per_portion, row.key), row.unit)}
            </td>
            <td class="text-right px-3 py-1 tabular-nums">
              {vd_cell(Map.fetch!(@per_portion, row.key), row.key)}
            </td>
          </tr>
        </tbody>
      </table>

      <div class="px-3 py-2 text-[10px] leading-snug border-t-[3px] border-black">
        <p>
          *Percentual de valores diários fornecidos pela porção. **VD não estabelecido.
          Valores diários de referência com base em uma dieta de 2.000 kcal ou 8.400 kJ.
        </p>
      </div>
    </div>
    """
  end

  # --- formatting ----------------------------------------------------------

  # Cell value for the 100 g / portion columns.
  defp cell(value, :energy) do
    kcal = round_to(value, 0)
    kj = round_to(value * 4.184, 0)
    "#{format_number(kcal, 0)} kcal = #{format_number(kj, 0)} kJ"
  end

  defp cell(value, :mg), do: "#{format_number(round_to(value, 0), 0)} mg"

  # Anvisa: amounts at or below 0.5 g are declared as "0 g".
  defp cell(value, :g) when value <= 0.5, do: "0 g"

  defp cell(value, :g) do
    decimals = if value >= 10, do: 0, else: 1
    "#{format_number(value, decimals)} g"
  end

  # %VD cell — "**" when no reference value exists (trans fat), else rounded %.
  defp vd_cell(value, key) do
    case Map.get(@reference_values, key) do
      vr when is_number(vr) and vr > 0 ->
        "#{format_number(round_to(value / vr * 100.0, 0), 0)}%"

      _ ->
        "**"
    end
  end

  # The portion basis: explicit serving size, else fall back to the whole
  # preparation weight (so the label is always meaningful), else 100 g.
  defp portion_grams(component, report) do
    cond do
      is_number(component.serving_size_g) and component.serving_size_g > 0 ->
        component.serving_size_g

      report.result.total_weight_g > 0 ->
        report.result.total_weight_g

      true ->
        100.0
    end
  end

  defp round_to(value, 0), do: Float.round(value * 1.0, 0)
  defp round_to(value, decimals), do: Float.round(value * 1.0, decimals)

  # Brazilian number formatting: comma decimal separator, no trailing ".0".
  defp format_number(value, 0), do: value |> round() |> Integer.to_string()

  defp format_number(value, decimals) do
    value
    |> Float.round(decimals)
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.replace(".", ",")
  end
end
