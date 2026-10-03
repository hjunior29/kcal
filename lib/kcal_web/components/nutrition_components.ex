defmodule KcalWeb.NutritionComponents do
  @moduledoc """
  The Anvisa-style nutrition label (Tabela / Informação Nutricional).

  Renders the strict element order required by Brazilian labelling rules
  (RDC 429/2020 + IN 75/2020): Valor energético, Carboidratos, Proteínas,
  Gorduras totais, Gorduras saturadas, Gorduras trans, Fibras alimentares, Sódio.

  Five renderers share the same data: `nutrition_facts/1` (vertical, Anexo IX),
  `nutrition_facts_broken/1` (vertical quebrado), `nutrition_facts_horizontal/1`,
  `nutrition_facts_linear/1` (Anexo XIII) and `nutrition_alerts/1` (the official
  front-of-pack "ALTO EM" seal per the malha construtiva).

  ## Faithfulness to the official models

  The table models reproduce the ANVISA Anexo IX artwork exactly: the **unit
  lives in the row label** ("Carboidratos (g)", "Sódio (mg)"), the value cells
  carry **bare numbers**, energy is **kcal-only**, the columns are headed
  "100 g | <porção> g | %VD*", and the box uses **hairline internal rules** with
  two **heavy rules** (below the porções block and above the footnote) — not the
  app's brutalist 3px grid. The seals reproduce the malha construtiva: a rounded
  white container, a "🔍 ALTO EM" header pill, then one rounded bar per nutrient.

  Because the app's global brutalist reset forces `border-radius: 0`, the seal's
  rounded corners are restored by `.alto-em-seal`/`.alto-em-bar` in `app.css`
  (they MUST live in the same `@layer base` as the reset to win the cascade).

  The whole label sits inside a `data-export-target` element so the client-side
  `NutritionExport` hook can rasterize it to PNG.
  """
  use Phoenix.Component

  import KcalWeb.CoreComponents, only: [icon: 1]

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

  # Row spec in the mandatory Anvisa order. `unit` drives both the label suffix
  # ("(kcal)", "(g)", "(mg)") and the bare-number cell formatting. `indent`
  # marks a sub-nutrient ("Gorduras saturadas" under "Gorduras totais").
  @rows [
    %{key: :energy_kcal, label: "Valor energético", unit: :energy},
    %{key: :carbohydrate_g, label: "Carboidratos", unit: :g},
    %{key: :protein_g, label: "Proteínas", unit: :g},
    %{key: :total_fat_g, label: "Gorduras totais", unit: :g},
    %{key: :saturated_fat_g, label: "Gorduras saturadas", unit: :g, indent: true},
    %{key: :trans_fat_g, label: "Gorduras trans", unit: :g, indent: true},
    %{key: :fiber_g, label: "Fibras alimentares", unit: :g},
    %{key: :sodium_mg, label: "Sódio", unit: :mg}
  ]

  # The "vertical quebrado" model splits the table after Proteínas (Anexo IX):
  # carbs group on the left, fats-and-beyond group on the right.
  @rows_group_a [:energy_kcal, :carbohydrate_g, :protein_g]
  @rows_group_b [:total_fat_g, :saturated_fat_g, :trans_fat_g, :fiber_g, :sodium_mg]

  # Front-of-pack "ALTO EM" thresholds — IN 75/2020 Anexo XV, for SOLID foods
  # evaluated per 100 g of the product as consumed.
  #
  # "Açúcar adicionado" (≥ 15 g/100 g) is deliberately absent: the TACO/TBCA
  # composition tables carry no sugar data — total or added — so the seal can't
  # be derived. It returns the moment an added-sugar field exists on Food.
  @front_thresholds [
    {:saturated_fat_g, "Gordura saturada", 6.0},
    {:sodium_mg, "Sódio", 600.0}
  ]

  # Informative "alto em" alerts — NOT the regulatory lupa. These use the UK FSA
  # front-of-pack "high" thresholds (per 100 g) for nutrients Brazil doesn't seal
  # but that are still worth flagging from the data we have. Rendered as a lighter
  # outlined seal so they're never confused with the official one.
  @info_thresholds [
    {:total_fat_g, "Gorduras totais", 17.5}
  ]

  @doc """
  Renders the nutrition label for a component report — the *vertical* model
  (Anexo IX, modelo 1).

    * `:report` — the map returned by `Kcal.Nutrition.component_report/1`
    * `:component` — the `%Component{}` (used for serving metadata)
    * `:title` — optional override for the box title
    * `:show_warnings` — front-of-pack "alto em" seals above the table
    * `:show_ingredients` — ingredient declaration block below the table
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :title, :string, default: "INFORMAÇÃO NUTRICIONAL"
  attr :class, :string, default: nil
  attr :show_warnings, :boolean, default: true, doc: "front-of-pack \"alto em\" seals"
  attr :show_ingredients, :boolean, default: true, doc: "ingredient declaration block"

  def nutrition_facts(assigns) do
    d = facts(assigns.component, assigns.report)

    assigns =
      assigns
      |> assign(:d, d)
      |> assign(:rows, @rows)
      |> assign(:warnings, front_warnings(assigns.report))
      |> assign(:info_alerts, info_alerts(assigns.report))
      |> assign(:ingredients, ingredient_names_desc(assigns.report))
      |> assign(:ingredients_text, ingredient_declaration(assigns.report))

    ~H"""
    <div data-export-target class={[nutrition_label_class(), "w-full max-w-md", @class]}>
      <%!-- Live-preview only: the front-of-pack seals. The Show page renders
            these as a standalone card, so it passes show_warnings={false}. --%>
      <div
        :if={@show_warnings and (@warnings != [] or @info_alerts != [])}
        class="border-b-[3px] border-black p-3"
      >
        <.alert_seals warnings={@warnings} info_alerts={@info_alerts} />
      </div>

      <div class="border-b border-black px-3 py-1.5 text-center">
        <h2 class="text-lg font-extrabold uppercase tracking-tight leading-none">{@title}</h2>
      </div>

      <.portions_block d={@d} />

      <table class="w-full border-collapse border-t-[3px] border-black text-[13px]">
        <thead>
          <.facts_head portion_g={@d.portion_g} />
        </thead>
        <tbody>
          <.facts_rows rows={@rows} per_100g={@d.per_100g} per_portion={@d.per_portion} />
        </tbody>
      </table>

      <%!-- Ingredient declaration, decreasing order of quantity (RDC 727/2022). --%>
      <div
        :if={@show_ingredients and @ingredients != []}
        class="border-t-[3px] border-black px-3 py-2 text-[11px] leading-snug"
      >
        <span class="font-bold uppercase">Ingredientes:</span> {@ingredients_text}
      </div>

      <.footnote class="border-t-[3px] border-black" />
    </div>
    """
  end

  @doc """
  The *horizontal* table model (Anexo IX, modelo 2): the title/portion block on
  the left, the value table on the right, footnote across the bottom.
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :class, :string, default: nil

  def nutrition_facts_horizontal(assigns) do
    assigns =
      assigns
      |> assign(:d, facts(assigns.component, assigns.report))
      |> assign(:rows, @rows)

    ~H"""
    <div data-export-target class={[nutrition_label_class(), "w-full max-w-3xl", @class]}>
      <div class="flex">
        <div class="w-48 shrink-0 border-r border-black p-3">
          <h2 class="text-lg font-extrabold uppercase leading-none">Informação<br />Nutricional</h2>
          <div class="mt-2 border-t-[3px] border-black pt-2 text-[12px] leading-snug">
            <p>Porções por emb.: <span class="font-bold">{@d.servings}</span></p>
            <p>Porção: <span class="font-bold">{format_number(@d.portion_g, 0)} g</span></p>
            <p :if={@d.servings_label not in [nil, ""]}>({@d.servings_label})</p>
          </div>
        </div>
        <table class="flex-1 border-collapse text-[12px]">
          <thead>
            <.facts_head portion_g={@d.portion_g} />
          </thead>
          <tbody>
            <.facts_rows rows={@rows} per_100g={@d.per_100g} per_portion={@d.per_portion} />
          </tbody>
        </table>
      </div>
      <.footnote class="border-t border-black" />
    </div>
    """
  end

  @doc """
  The *horizontal quebrado* table model (Anexo IX, modelo 4): the title/portion
  block on the left, then the value table split into two groups side by side
  (carbs group | fats-and-beyond), footnote across the bottom.
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :class, :string, default: nil

  def nutrition_facts_horizontal_broken(assigns) do
    assigns =
      assigns
      |> assign(:d, facts(assigns.component, assigns.report))
      |> assign(:rows_a, rows_for(@rows_group_a))
      |> assign(:rows_b, rows_for(@rows_group_b))

    ~H"""
    <div data-export-target class={[nutrition_label_class(), "w-full max-w-5xl", @class]}>
      <div class="flex">
        <div class="w-48 shrink-0 border-r border-black p-3">
          <h2 class="text-lg font-extrabold uppercase leading-none">Informação<br />Nutricional</h2>
          <div class="mt-2 border-t-[3px] border-black pt-2 text-[12px] leading-snug">
            <p>Porções por emb.: <span class="font-bold">{@d.servings}</span></p>
            <p>Porção: <span class="font-bold">{format_number(@d.portion_g, 0)} g</span></p>
            <p :if={@d.servings_label not in [nil, ""]}>({@d.servings_label})</p>
          </div>
        </div>
        <table class="flex-1 border-collapse text-[12px]">
          <thead>
            <.facts_head portion_g={@d.portion_g} />
          </thead>
          <tbody>
            <.facts_rows rows={@rows_a} per_100g={@d.per_100g} per_portion={@d.per_portion} />
          </tbody>
        </table>
        <table class="flex-1 border-collapse border-l border-black text-[12px]">
          <thead>
            <.facts_head portion_g={@d.portion_g} />
          </thead>
          <tbody>
            <.facts_rows rows={@rows_b} per_100g={@d.per_100g} per_portion={@d.per_portion} />
          </tbody>
        </table>
      </div>
      <.footnote class="border-t border-black" />
    </div>
    """
  end

  @doc """
  The *vertical quebrado* table model (Anexo IX, modelo 3): a shared centered
  header, then two value tables side by side (carbs group | fats-and-beyond).
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :class, :string, default: nil

  def nutrition_facts_broken(assigns) do
    assigns =
      assigns
      |> assign(:d, facts(assigns.component, assigns.report))
      |> assign(:rows_a, rows_for(@rows_group_a))
      |> assign(:rows_b, rows_for(@rows_group_b))

    ~H"""
    <div data-export-target class={[nutrition_label_class(), "w-full max-w-3xl", @class]}>
      <div class="border-b border-black px-3 py-1.5 text-center">
        <h2 class="text-lg font-extrabold uppercase leading-none">Informação Nutricional</h2>
      </div>
      <div class="px-3 py-1 text-[12px] leading-tight">
        Porções por embalagem: <span class="font-bold">{@d.servings}</span>
        • Porção: <span class="font-bold">{format_number(@d.portion_g, 0)} g</span>{caseira(@d)}
      </div>
      <div class="grid grid-cols-1 border-t-[3px] border-black sm:grid-cols-2">
        <table class="w-full border-collapse text-[12px]">
          <thead>
            <.facts_head portion_g={@d.portion_g} />
          </thead>
          <tbody>
            <.facts_rows rows={@rows_a} per_100g={@d.per_100g} per_portion={@d.per_portion} />
          </tbody>
        </table>
        <table class="w-full border-collapse border-black text-[12px] border-t sm:border-t-0 sm:border-l">
          <thead>
            <.facts_head portion_g={@d.portion_g} />
          </thead>
          <tbody>
            <.facts_rows rows={@rows_b} per_100g={@d.per_100g} per_portion={@d.per_portion} />
          </tbody>
        </table>
      </div>
      <.footnote class="border-t-[3px] border-black" />
    </div>
    """
  end

  @doc """
  Anvisa's *linear* (running-text) declaration — Anexo XIII. Per-100 g values
  with the per-portion amount and %VD in parentheses, bullets between major
  nutrients and "das quais" introducing the sub-nutrients.
  """
  attr :report, :map, required: true
  attr :component, :map, required: true
  attr :class, :string, default: nil

  def nutrition_facts_linear(assigns) do
    d = facts(assigns.component, assigns.report)

    assigns =
      assigns
      |> assign(:d, d)
      |> assign(:body, linear_body(d.per_100g, d.per_portion))

    ~H"""
    <div
      data-export-target
      class={[nutrition_label_class(), "w-full p-3 text-[13px] leading-relaxed", @class]}
    >
      <p class="font-extrabold uppercase">Informação nutricional</p>
      <p class="text-[12px]">
        Porções por embalagem: {@d.servings} • Porção: {format_number(@d.portion_g, 0)} g{caseira(@d)}
      </p>
      <p class="mt-1">
        <span class="font-semibold">Por 100 g (porção, %VD*):</span> {@body}.
      </p>
      <p class="mt-2 text-[10px] opacity-70">
        *Percentual de valores diários fornecidos pela porção. **VD não estabelecido.
      </p>
    </div>
    """
  end

  @doc """
  Standalone "alto em" seals card — the front-of-pack symbol on its own, with a
  `data-export-target` so it can be downloaded/copied independently of the
  tables. Renders nothing when there are no alerts. No outer border: the seal is
  its own rounded container (the malha construtiva), so wrapping it in the app's
  square box would be wrong.
  """
  attr :report, :map, required: true
  attr :class, :string, default: nil

  def nutrition_alerts(assigns) do
    assigns =
      assigns
      |> assign(:warnings, front_warnings(assigns.report))
      |> assign(:info_alerts, info_alerts(assigns.report))

    ~H"""
    <%!-- No background here: each seal is its own white container, and the
          export hook paints the PNG background white. A transparent wrapper
          keeps the on-page view to just the rounded seals (no redundant box). --%>
    <div
      :if={@warnings != [] or @info_alerts != []}
      data-export-target
      class={["inline-block p-2", @class]}
    >
      <.alert_seals warnings={@warnings} info_alerts={@info_alerts} />
    </div>
    """
  end

  @doc """
  Icon-only export controls (download + copy) for a `NutritionExport` wrapper.
  Place inside the same element that carries `phx-hook="NutritionExport"`.
  """
  def export_buttons(assigns) do
    ~H"""
    <div class="mt-3 flex items-center gap-2">
      <button
        type="button"
        data-export="download"
        title="Baixar imagem"
        aria-label="Baixar imagem"
        class="rounded-none border-2 border-black bg-brand p-2 text-black hover:bg-black hover:text-white"
      >
        <.icon name="hero-arrow-down-tray" class="size-5" />
      </button>
      <button
        type="button"
        data-export="copy"
        title="Copiar imagem"
        aria-label="Copiar imagem"
        class="rounded-none border-2 border-black bg-white p-2 text-black hover:bg-brand"
      >
        <.icon name="hero-document-duplicate" class="size-5" />
      </button>
      <span data-export-status class="text-xs opacity-70" aria-live="polite"></span>
    </div>
    """
  end

  @doc """
  The "ALTO EM" front-of-pack symbol per the malha construtiva: a single rounded
  white block — a "🔍 ALTO EM" header pill on top, then one stacked black bar per
  nutrient. The composition naturally adapts to the number of nutrients (one bar
  for one alert, two for two, three for three, …).

  `variant` is `"filled"` (the official black seal) or `"outline"` (our
  informative alerts — same shape, hollow bars, so it can't be mistaken for the
  legal seal). Public so the live preview/exports and tests can render an
  arbitrary list of nutrients.
  """
  attr :items, :list, required: true
  attr :variant, :string, default: "filled"

  # No nutrients → no seal (a seal with zero bars would claim "high in nothing").
  def alto_em_block(%{items: []} = assigns), do: ~H""

  def alto_em_block(assigns) do
    ~H"""
    <div class="alto-em-seal inline-flex w-44 flex-col gap-2 border-[3px] border-black bg-white p-2 text-black">
      <%!-- "ALTO EM" header in its own pill, same width as the bars below. --%>
      <div class="alto-em-bar flex items-center gap-1.5 border-[3px] border-black px-2.5 py-1.5">
        <.alert_lens class="size-6" />
        <span class="text-base font-extrabold uppercase leading-none tracking-tight">Alto em</span>
      </div>
      <%!-- One bar per nutrient. Long names wrap to two lines and bars grow to
            fit, as in the malha (e.g. "AÇÚCAR / ADICIONADO"). --%>
      <div
        :for={item <- @items}
        class={[
          "alto-em-bar flex items-center justify-center px-3 py-2.5 text-center",
          @variant == "filled" && "bg-black",
          @variant == "outline" && "border-[3px] border-black bg-white"
        ]}
      >
        <span class={[
          "text-base font-extrabold uppercase leading-[1.05] tracking-tight",
          @variant == "filled" && "text-white",
          @variant == "outline" && "text-black"
        ]}>
          {item}
        </span>
      </div>
    </div>
    """
  end

  # The seal(s) shared by the live-preview's inline alerts and the standalone
  # alerts card: the official front-of-pack symbol plus any informative,
  # non-regulatory seal below.
  attr :warnings, :list, required: true
  attr :info_alerts, :list, required: true

  defp alert_seals(assigns) do
    ~H"""
    <div class="flex flex-wrap items-start gap-3">
      <.alto_em_block :if={@warnings != []} items={@warnings} variant="filled" />

      <div :if={@info_alerts != []} class="space-y-1">
        <.alto_em_block items={@info_alerts} variant="outline" />
        <p class="w-44 text-[9px] uppercase tracking-wide opacity-60 leading-tight">
          Alertas informativos (não obrigatórios).<span :if={@warnings != []}>
            O selo preenchido é a rotulagem frontal obrigatória (IN 75/2020).</span>
        </p>
      </div>
    </div>
    """
  end

  # The shared "Porções por embalagem / Porção" block (Anexo IX vertical).
  attr :d, :map, required: true

  defp portions_block(assigns) do
    ~H"""
    <div class="px-3 py-1 text-[13px] leading-tight">
      <p>Porções por embalagem: <span class="font-bold">{@d.servings}</span></p>
      <p>Porção: <span class="font-bold">{format_number(@d.portion_g, 0)} g</span>{caseira(@d)}</p>
    </div>
    """
  end

  # The "100 g | <porção> g | %VD*" column header, shared by every table model.
  # Hairline vertical rules separate the three numeric columns.
  attr :portion_g, :float, required: true

  defp facts_head(assigns) do
    ~H"""
    <tr class="border-b border-black">
      <td class="px-3 py-1 text-left"></td>
      <th scope="col" class="w-[20%] border-l border-black px-2 py-1 text-right font-bold">100 g</th>
      <th scope="col" class="w-[22%] border-l border-black px-2 py-1 text-right font-bold">
        {format_number(@portion_g, 0)} g
      </th>
      <th scope="col" class="w-[16%] border-l border-black px-3 py-1 text-right font-bold">
        %VD*
      </th>
    </tr>
    """
  end

  # The nutrient value rows, shared by every table model. The unit lives in the
  # label ("Carboidratos (g)"); the cells carry bare numbers. Hairline rules
  # between rows; the last row drops its rule so the heavy footnote rule shows.
  attr :rows, :list, required: true
  attr :per_100g, :map, required: true
  attr :per_portion, :map, required: true

  defp facts_rows(assigns) do
    ~H"""
    <tr :for={row <- @rows} class="border-b border-black/40 last:border-b-0">
      <th scope="row" class={["px-3 py-1 text-left font-normal", row[:indent] && "pl-6"]}>
        {label_with_unit(row)}
      </th>
      <td class="border-l border-black/40 px-2 py-1 text-right tabular-nums">
        {cell_value(Map.fetch!(@per_100g, row.key), row.unit)}
      </td>
      <td class="border-l border-black/40 px-2 py-1 text-right tabular-nums">
        {cell_value(Map.fetch!(@per_portion, row.key), row.unit)}
      </td>
      <td class="border-l border-black/40 px-3 py-1 text-right tabular-nums">
        {vd_cell(Map.fetch!(@per_portion, row.key), row.key)}
      </td>
    </tr>
    """
  end

  # The shared footnote line. `class` carries the (heavy or hairline) top rule.
  attr :class, :string, default: nil

  defp footnote(assigns) do
    ~H"""
    <p class={["px-3 py-1 text-[10px] leading-snug", @class]}>
      *Percentual de valores diários fornecidos pela porção. **VD não estabelecido.
    </p>
    """
  end

  # The magnifying-glass mark, matching the official symbol orientation (lens
  # up, handle down-left at ~30°). Inline SVG so it rasterizes reliably.
  attr :class, :string, default: "size-5"

  defp alert_lens(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.6"
      aria-hidden="true"
      focusable="false"
      class={[@class, "shrink-0"]}
    >
      <circle cx="14" cy="9" r="5.2" />
      <line x1="10.1" y1="12.9" x2="4" y2="19" stroke-linecap="round" />
    </svg>
    """
  end

  # --- label data ----------------------------------------------------------

  @doc """
  Active front-of-pack "ALTO EM" warnings for a report, as human labels
  (e.g. `["Gordura saturada", "Sódio"]`). A nutrient warns when its per-100 g
  amount reaches the IN 75/2020 threshold. Empty when nothing is high.
  """
  def front_warnings(report) do
    per_100g = report.per_100g

    for {field, label, limit} <- @front_thresholds,
        Map.fetch!(per_100g, field) >= limit,
        do: label
  end

  @doc """
  Informative (non-regulatory) "alto em" alerts derived from the data we have —
  high total fat (FSA threshold) and any presence of trans fat. Distinct from
  `front_warnings/1`, which are the official IN 75/2020 seals.
  """
  def info_alerts(report) do
    per_100g = report.per_100g

    threshold_alerts =
      for {field, label, limit} <- @info_thresholds,
          Map.fetch!(per_100g, field) >= limit,
          do: label

    # Any amount of trans fat is worth flagging (WHO: minimize/eliminate).
    if per_100g.trans_fat_g > 0,
      do: threshold_alerts ++ ["Gordura trans"],
      else: threshold_alerts
  end

  @doc """
  Ingredient names in decreasing order of mass — the order Brazilian labelling
  requires for the ingredient declaration. Lines with no resolvable mass are
  dropped; duplicate names are collapsed keeping the heaviest occurrence first.
  Each name is cleaned with `ingredient_label/1`.
  """
  def ingredient_names_desc(report) do
    report.result.lines
    |> Enum.filter(&(&1.grams > 0))
    |> Enum.sort_by(& &1.grams, :desc)
    |> Enum.map(&ingredient_label(&1.label))
    |> Enum.uniq()
  end

  @doc """
  Cleans a food/component name for display as a single ingredient. TACO uses an
  inverted, comma-separated format ("Queijo, cru", "Frango, peito, sem pele")
  that, joined into a list, reads as if each qualifier were its own ingredient.
  We flatten the internal commas to spaces so "Queijo, cru" → "Queijo cru".
  """
  def ingredient_label(name) when is_binary(name) do
    name
    |> String.replace(~r/,\s*/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  def ingredient_label(name), do: name

  @doc """
  The Brazilian ingredient declaration sentence, in decreasing order of mass:
  lower-cased names, the last joined with "e", first letter capitalized, ending
  with a period — e.g. "Queijo cru, arroz integral e sal.". `""` when empty.
  """
  def ingredient_declaration(report) do
    case report |> ingredient_names_desc() |> Enum.map(&String.downcase/1) do
      [] -> ""
      names -> names |> join_with_e() |> capitalize_first() |> Kernel.<>(".")
    end
  end

  # Natural-language list join: "a", "a e b", "a, b e c".
  defp join_with_e([only]), do: only
  defp join_with_e([a, b]), do: "#{a} e #{b}"

  defp join_with_e(list) do
    {init, [last]} = Enum.split(list, -1)
    "#{Enum.join(init, ", ")} e #{last}"
  end

  defp capitalize_first(""), do: ""
  defp capitalize_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  # Common per-label data, computed once and shared by every table model.
  defp facts(component, report) do
    portion_g = portion_grams(component, report)
    total_weight_g = report.result.total_weight_g

    %{
      portion_g: portion_g,
      total_weight_g: total_weight_g,
      servings: servings_per_package(total_weight_g, portion_g),
      per_100g: report.per_100g,
      per_portion: Calculator.per_serving(report.result, portion_g) || Nutrients.zero(),
      servings_label: component.servings_label
    }
  end

  # Row specs for a subset of keys, preserving the canonical Anvisa order.
  defp rows_for(keys), do: Enum.filter(@rows, &(&1.key in keys))

  # Builds the Anexo XIII running text: "Nome <por 100 g> (<porção>, <%VD>)",
  # majors joined by " • ", sub-nutrients introduced with "das quais".
  defp linear_body(p100, pp) do
    seg = fn key, label, unit ->
      v100 = linear_value(Map.fetch!(p100, key), unit)
      vpp = linear_value(Map.fetch!(pp, key), unit)

      case vd_cell(Map.fetch!(pp, key), key) do
        "**" -> "#{label} #{v100} (#{vpp}, **)"
        pct -> "#{label} #{v100} (#{vpp}, #{pct})"
      end
    end

    fats =
      "#{seg.(:total_fat_g, "Gorduras totais", :g)}, das quais " <>
        "#{seg.(:saturated_fat_g, "Gorduras saturadas", :g)}, " <>
        "#{seg.(:trans_fat_g, "Gorduras trans", :g)}"

    [
      seg.(:energy_kcal, "Valor energético", :energy),
      seg.(:carbohydrate_g, "Carboidratos", :g),
      seg.(:protein_g, "Proteínas", :g),
      fats,
      seg.(:fiber_g, "Fibras alimentares", :g),
      seg.(:sodium_mg, "Sódio", :mg)
    ]
    |> Enum.join(" • ")
  end

  # The linear (running-text) value keeps its unit inline ("12 g", "453 kcal").
  defp linear_value(value, :energy), do: "#{format_number(round_to(value, 0), 0)} kcal"
  defp linear_value(value, :mg), do: "#{format_number(round_to(value, 0), 0)} mg"
  defp linear_value(value, :g) when value <= 0.5, do: "0 g"

  defp linear_value(value, :g) do
    decimals = if value >= 10, do: 0, else: 1
    "#{format_number(value, decimals)} g"
  end

  # --- formatting ----------------------------------------------------------

  # The row label with its unit ("Carboidratos (g)"). A non-breaking space keeps
  # the "(unit)" glued to the last word, so a narrow column wraps as
  # "Gorduras / saturadas (g)" — never an orphaned "(g)" on its own line.
  defp label_with_unit(row), do: "#{row.label} (#{unit_label(row.unit)})"

  # The unit suffix shown in the row label (the cells stay bare numbers).
  defp unit_label(:energy), do: "kcal"
  defp unit_label(:mg), do: "mg"
  defp unit_label(:g), do: "g"

  # Bare-number cell value for the 100 g / porção columns (unit is in the label).
  defp cell_value(value, :energy), do: format_number(round_to(value, 0), 0)
  defp cell_value(value, :mg), do: format_number(round_to(value, 0), 0)
  # Anvisa: amounts at or below 0.5 g are declared as "0".
  defp cell_value(value, :g) when value <= 0.5, do: "0"

  defp cell_value(value, :g) do
    decimals = if value >= 10, do: 0, else: 1
    format_number(value, decimals)
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

  # The "(medida caseira)" tail for the Porção line — the servings label when set.
  defp caseira(%{servings_label: l}) when is_binary(l) and l != "", do: " (#{l})"
  defp caseira(_), do: ""

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

  # How many WHOLE portions the preparation yields (Porções por embalagem). We
  # floor — never claim more servings than the package holds — with a tiny
  # epsilon so an exact division that lands at x.9999 (float error) still counts.
  defp servings_per_package(total_weight_g, portion_g)
       when is_number(total_weight_g) and is_number(portion_g) and total_weight_g > 0 and
              portion_g > 0,
       do: max(trunc(total_weight_g / portion_g + 1.0e-6), 1)

  defp servings_per_package(_total_weight_g, _portion_g), do: 1

  # The shared outer wrapper for every table model: white background, hairline
  # black border, sans-serif. Deliberately *not* the app's brutalist 3px grid —
  # the Anexo IX artwork uses thin rules.
  defp nutrition_label_class do
    "inline-block border-[1.5px] border-black bg-white text-black font-sans"
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
