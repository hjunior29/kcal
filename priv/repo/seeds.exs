# ============================================================================
# Database seeds for the Kcal nutrition app.
#
# Run with:
#
#     mix run priv/repo/seeds.exs
#
# Data sources
# ------------
#   * TACO  — Tabela Brasileira de Composição de Alimentos, NEPA/UNICAMP,
#             4ª edição revisada e ampliada (2011). The COMPLETE table (~597
#             foods) is loaded from the vendored CSVs in `priv/repo/data/`:
#               - taco_alimentos.csv       (macros, fibra, sódio)
#               - taco_acidos_graxos.csv   (gordura saturada e trans)
#             The two are joined on the food number ("Número do Alimento").
#             Source: https://github.com/machine-learning-mocha/taco
#   * TBCA  — a small curated supplement of common industrializados (USP/FoRC)
#             not present in TACO.
#
# Basis & accuracy
# ----------------
#   * ALL nutrient values are expressed **per 100 g of edible portion**, the
#     reference basis used by both TACO and TBCA.
#   * In the source CSVs, `NA` means "não disponível" and the placeholder
#     `1e-05` means "traço" (trace) — both are coerced to 0.0 here.
#   * Values are for educational use only; not for clinical/regulatory use.
#
# Idempotency & FK safety
# -----------------------
#   * Measure units are upserted on the unique `:abbreviation`.
#   * TACO foods are upserted keyed on (`:source`, `:source_code`), so
#     re-running never duplicates them.
#   * TBCA foods are upserted keyed on `:name`.
#   * We never delete foods (they may be referenced by `component_items`,
#     ON DELETE RESTRICT). For a pristine reload run `mix ecto.reset`.
# ============================================================================

alias Kcal.Repo
alias Kcal.Nutrition.{Food, MeasureUnit}

NimbleCSV.define(Kcal.Seeds.TacoCSV, separator: ",", escape: "\"")

data_dir = Path.join(:code.priv_dir(:kcal), "repo/data")

# Coerce a TACO cell ("NA", "1e-05" trace, or a number) to a float >= 0.0.
parse_num = fn
  nil ->
    0.0

  cell ->
    case String.trim(cell) do
      "" ->
        0.0

      "NA" ->
        0.0

      str ->
        case Float.parse(str) do
          {n, _} when n < 0.001 -> 0.0
          {n, _} -> Float.round(n, 3)
          :error -> 0.0
        end
    end
end

# ----------------------------------------------------------------------------
# Measure units (order matters — the unit converter relies on these positions).
# ----------------------------------------------------------------------------
measure_units = [
  %{name: "Grama", abbreviation: "g", grams_per_unit: 1.0, kind: "mass", position: 0},
  %{name: "Quilograma", abbreviation: "kg", grams_per_unit: 1000.0, kind: "mass", position: 1},
  %{name: "Mililitro", abbreviation: "ml", grams_per_unit: 1.0, kind: "volume", position: 2},
  %{name: "Litro", abbreviation: "l", grams_per_unit: 1000.0, kind: "volume", position: 3},
  %{name: "Colher de chá", abbreviation: "cdc", grams_per_unit: 5.0, kind: "volume", position: 4},
  %{
    name: "Colher de sopa",
    abbreviation: "cds",
    grams_per_unit: 15.0,
    kind: "volume",
    position: 5
  },
  %{name: "Xícara", abbreviation: "xíc", grams_per_unit: 240.0, kind: "volume", position: 6},
  # `grams_per_unit` is nil on purpose: a count unit has no global gram default
  # and requires a per-item `grams_per_unit_override`.
  %{name: "Unidade", abbreviation: "un", grams_per_unit: nil, kind: "count", position: 7}
]

for attrs <- measure_units do
  %MeasureUnit{}
  |> MeasureUnit.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :abbreviation)
end

# ----------------------------------------------------------------------------
# TACO — fatty acids table → map: food number => %{saturated, trans}.
# Columns (0-based): 0 Número, 3 Saturados, 23 X18.1t, 24 X18.2t (trans isomers).
# ----------------------------------------------------------------------------
fats_by_code =
  data_dir
  |> Path.join("taco_acidos_graxos.csv")
  |> File.read!()
  |> Kcal.Seeds.TacoCSV.parse_string(skip_headers: true)
  |> Map.new(fn row ->
    code = row |> Enum.at(0) |> String.trim()
    saturated = parse_num.(Enum.at(row, 3))
    trans = parse_num.(Enum.at(row, 23)) + parse_num.(Enum.at(row, 24))
    {code, %{saturated_fat_g: saturated, trans_fat_g: Float.round(trans, 3)}}
  end)

# ----------------------------------------------------------------------------
# TACO — main table → full list of food attrs (merging saturated/trans fats).
# Columns (0-based): 0 Número, 1 Categoria, 2 Descrição, 4 Energia kcal,
# 6 Proteína, 7 Lipídeos, 9 Carboidrato, 10 Fibra, 17 Sódio.
# ----------------------------------------------------------------------------
taco_foods =
  data_dir
  |> Path.join("taco_alimentos.csv")
  |> File.read!()
  |> Kcal.Seeds.TacoCSV.parse_string(skip_headers: true)
  |> Enum.map(fn row ->
    code = row |> Enum.at(0) |> String.trim()
    fats = Map.get(fats_by_code, code, %{saturated_fat_g: 0.0, trans_fat_g: 0.0})

    %{
      name: row |> Enum.at(2) |> String.trim(),
      category: row |> Enum.at(1) |> String.trim(),
      source: "TACO",
      source_code: code,
      energy_kcal: parse_num.(Enum.at(row, 4)),
      protein_g: parse_num.(Enum.at(row, 6)),
      total_fat_g: parse_num.(Enum.at(row, 7)),
      carbohydrate_g: parse_num.(Enum.at(row, 9)),
      fiber_g: parse_num.(Enum.at(row, 10)),
      sodium_mg: parse_num.(Enum.at(row, 17)),
      saturated_fat_g: fats.saturated_fat_g,
      trans_fat_g: fats.trans_fat_g
    }
  end)

# ----------------------------------------------------------------------------
# TBCA — curated supplement of common industrializados not present in TACO.
# ----------------------------------------------------------------------------
tbca_foods = [
  %{
    name: "Atum, em conserva (sólido em óleo)",
    category: "Pescados",
    source: "TBCA",
    source_code: nil,
    energy_kcal: 166.0,
    carbohydrate_g: 0.0,
    protein_g: 25.5,
    total_fat_g: 6.8,
    saturated_fat_g: 1.3,
    trans_fat_g: 0.0,
    fiber_g: 0.0,
    sodium_mg: 354.0
  },
  %{
    name: "Requeijão, cremoso",
    category: "Leite e derivados",
    source: "TBCA",
    source_code: nil,
    energy_kcal: 257.0,
    carbohydrate_g: 3.0,
    protein_g: 9.6,
    total_fat_g: 23.0,
    saturated_fat_g: 14.5,
    trans_fat_g: 0.4,
    fiber_g: 0.0,
    sodium_mg: 490.0
  },
  %{
    name: "Pasta de amendoim, integral",
    category: "Oleaginosas",
    source: "TBCA",
    source_code: nil,
    energy_kcal: 588.0,
    carbohydrate_g: 20.0,
    protein_g: 25.0,
    total_fat_g: 50.0,
    saturated_fat_g: 9.0,
    trans_fat_g: 0.0,
    fiber_g: 6.0,
    sodium_mg: 17.0
  },
  %{
    name: "Refrigerante, tipo cola",
    category: "Bebidas",
    source: "TBCA",
    source_code: nil,
    energy_kcal: 42.0,
    carbohydrate_g: 10.6,
    protein_g: 0.0,
    total_fat_g: 0.0,
    saturated_fat_g: 0.0,
    trans_fat_g: 0.0,
    fiber_g: 0.0,
    sodium_mg: 7.0
  }
]

# ----------------------------------------------------------------------------
# Upsert. TACO keyed on (source, source_code); TBCA keyed on name.
# ----------------------------------------------------------------------------
upsert = fn attrs, existing ->
  case existing do
    nil -> Repo.insert!(Food.changeset(%Food{}, attrs))
    food -> Repo.update!(Food.changeset(food, attrs))
  end
end

for attrs <- taco_foods do
  upsert.(attrs, Repo.get_by(Food, source: "TACO", source_code: attrs.source_code))
end

for attrs <- tbca_foods do
  upsert.(attrs, Repo.get_by(Food, name: attrs.name))
end

# ----------------------------------------------------------------------------
# Summary.
# ----------------------------------------------------------------------------
IO.puts("""
Seed complete.
  MeasureUnit count: #{Repo.aggregate(MeasureUnit, :count, :id)}
  Food count:        #{Repo.aggregate(Food, :count, :id)} (TACO + TBCA)
""")
