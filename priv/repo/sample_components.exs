# Optional demo data: builds two components — one nested inside the other —
# to exercise the calculator and give the dashboard something to show.
# Idempotent: skips a component whose name already exists.
#
#     mix run priv/repo/sample_components.exs

import Ecto.Query
alias Kcal.Repo
alias Kcal.Nutrition
alias Kcal.Nutrition.{Component, Food, MeasureUnit}

g = Repo.one!(from u in MeasureUnit, where: u.abbreviation == "g")

food! = fn name ->
  Repo.one!(from f in Food, where: f.name == ^name)
end

get_or_create = fn name, build ->
  case Repo.get_by(Component, name: name) do
    nil ->
      {:ok, component} = Nutrition.create_component(build.())
      IO.puts("  criado: #{name}")
      component

    existing ->
      IO.puts("  já existe: #{name}")
      existing
  end
end

frango =
  get_or_create.("Frango com marinado oriental", fn ->
    peito = food!.("Frango, peito, sem pele, grelhado")

    %{
      "name" => "Frango com marinado oriental",
      "description" => "Peito de frango grelhado com toque oriental",
      "serving_size_g" => 150.0,
      "servings_label" => "1 filé",
      "items" => [
        %{"food_id" => peito.id, "measure_unit_id" => g.id, "quantity" => 200.0, "position" => 0}
      ]
    }
  end)

_marmita =
  get_or_create.("Marmita fitness", fn ->
    arroz = food!.("Arroz, integral, cozido")
    feijao = food!.("Feijão, carioca, cozido")

    %{
      "name" => "Marmita fitness",
      "description" => "Arroz integral, feijão e frango oriental",
      "serving_size_g" => 450.0,
      "servings_label" => "1 marmita",
      "items" => [
        %{"food_id" => arroz.id, "measure_unit_id" => g.id, "quantity" => 150.0, "position" => 0},
        %{"food_id" => feijao.id, "measure_unit_id" => g.id, "quantity" => 100.0, "position" => 1},
        %{
          "child_component_id" => frango.id,
          "measure_unit_id" => g.id,
          "quantity" => 200.0,
          "position" => 2
        }
      ]
    }
  end)

report = Nutrition.component_report(Repo.get_by!(Component, name: "Marmita fitness"))

IO.puts("\n=== Marmita fitness ===")
IO.puts("Peso total: #{Float.round(report.result.total_weight_g, 1)} g")
IO.puts("Energia total: #{Float.round(report.result.nutrients.energy_kcal, 1)} kcal")
IO.puts("Proteína total: #{Float.round(report.result.nutrients.protein_g, 1)} g")
IO.puts("Sódio total: #{Float.round(report.result.nutrients.sodium_mg, 1)} mg")
IO.puts("--- por 100 g ---")
IO.puts("Energia/100g: #{Float.round(report.per_100g.energy_kcal, 1)} kcal")
IO.puts("Proteína/100g: #{Float.round(report.per_100g.protein_g, 1)} g")
IO.puts("--- por porção (450 g) ---")
IO.puts("Energia/porção: #{Float.round(report.per_serving.energy_kcal, 1)} kcal")
IO.puts("Proteína/porção: #{Float.round(report.per_serving.protein_g, 1)} g")
