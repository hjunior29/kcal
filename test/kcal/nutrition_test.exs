defmodule Kcal.NutritionTest do
  @moduledoc "Context-level tests: read-only reference data and in-memory reporting."
  use Kcal.DataCase, async: true

  alias Kcal.Nutrition
  alias Kcal.Nutrition.{Food, MeasureUnit}

  setup do
    {:ok, gram} =
      %MeasureUnit{}
      |> MeasureUnit.changeset(%{
        name: "Grama",
        abbreviation: "g",
        grams_per_unit: 1.0,
        kind: "mass",
        position: 0
      })
      |> Repo.insert()

    {:ok, rice} =
      %Food{}
      |> Food.changeset(%{
        name: "Arroz, integral, cozido",
        source: "TACO",
        energy_kcal: 124.0,
        protein_g: 2.6,
        carbohydrate_g: 25.8,
        total_fat_g: 1.0,
        fiber_g: 2.7,
        sodium_mg: 1.0
      })
      |> Repo.insert()

    {:ok, chicken} =
      %Food{}
      |> Food.changeset(%{
        name: "Frango, peito, grelhado",
        source: "TACO",
        energy_kcal: 159.0,
        protein_g: 32.0,
        total_fat_g: 2.5
      })
      |> Repo.insert()

    %{gram: gram, rice: rice, chicken: chicken}
  end

  test "search_foods/2 finds foods ignoring accents and case", %{rice: rice} do
    results = Nutrition.search_foods("arroz")
    assert Enum.any?(results, &(&1.id == rice.id))

    # Diacritic stripping: searching "integrál" matches "integral"
    results_accent = Nutrition.search_foods("integrál")
    assert Enum.any?(results_accent, &(&1.id == rice.id))
  end

  test "get_food/1 and get_food!/1 return the food", %{rice: rice} do
    assert Nutrition.get_food(rice.id).name == rice.name
    assert Nutrition.get_food!(rice.id).id == rice.id
    assert Nutrition.get_food(-999) == nil
  end

  test "list_measure_units/0 and default_measure_unit/0", %{gram: gram} do
    units = Nutrition.list_measure_units()
    assert Enum.any?(units, &(&1.id == gram.id))

    default = Nutrition.default_measure_unit()
    assert default.abbreviation == "g"
  end

  test "report_for/1 computes in-memory nutritional totals without database writes", %{
    gram: g,
    rice: rice,
    chicken: chicken
  } do
    recipe = %{
      name: "Prato Fitness",
      description: "Arroz integral e frango grelhado",
      serving_size_g: 250.0,
      servings_label: "1 prato",
      items: [
        %{
          food_id: rice.id,
          food: rice,
          measure_unit_id: g.id,
          measure_unit: g,
          quantity: 150.0,
          grams_per_unit_override: nil
        },
        %{
          food_id: chicken.id,
          food: chicken,
          measure_unit_id: g.id,
          measure_unit: g,
          quantity: 100.0,
          grams_per_unit_override: nil
        }
      ]
    }

    report = Nutrition.report_for(recipe)

    # Total weight: 150 + 100 = 250g
    assert_in_delta report.result.total_weight_g, 250.0, 0.001
    # Energy: (1.5 * 124) + (1.0 * 159) = 186 + 159 = 345 kcal
    assert_in_delta report.result.nutrients.energy_kcal, 345.0, 0.001
    # Protein: (1.5 * 2.6) + (1.0 * 32) = 3.9 + 32 = 35.9 g
    assert_in_delta report.result.nutrients.protein_g, 35.9, 0.001

    # Per serving (250g): equal to total since serving size is 250g
    assert_in_delta report.per_serving.energy_kcal, 345.0, 0.001
    assert_in_delta report.per_serving.protein_g, 35.9, 0.001

    # Per 100g: 345 / 2.5 = 138 kcal
    assert_in_delta report.per_100g.energy_kcal, 138.0, 0.001
  end
end
