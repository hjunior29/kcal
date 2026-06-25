defmodule Kcal.Nutrition.CalculatorTest do
  @moduledoc "Pure tests for the nutrient math — no database involved."
  use ExUnit.Case, async: true

  alias Kcal.Nutrition.{Calculator, Component, ComponentItem, Food, MeasureUnit}

  defp gram, do: %MeasureUnit{id: 1, abbreviation: "g", grams_per_unit: 1.0, kind: "mass"}
  defp tbsp, do: %MeasureUnit{id: 2, abbreviation: "cds", grams_per_unit: 15.0, kind: "volume"}
  defp counted, do: %MeasureUnit{id: 3, abbreviation: "un", grams_per_unit: nil, kind: "count"}

  defp food(attrs) do
    struct(
      %Food{
        name: "x",
        energy_kcal: 0.0,
        carbohydrate_g: 0.0,
        protein_g: 0.0,
        total_fat_g: 0.0,
        saturated_fat_g: 0.0,
        trans_fat_g: 0.0,
        fiber_g: 0.0,
        sodium_mg: 0.0
      },
      attrs
    )
  end

  defp comp(id, items), do: %Component{id: id, items: items}
  defp no_loader, do: fn _ -> nil end

  test "a food line scales the per-100 g profile by grams" do
    item = %ComponentItem{
      food: food(%{energy_kcal: 130.0, protein_g: 2.5}),
      food_id: 1,
      measure_unit: gram(),
      quantity: 200.0
    }

    res = Calculator.totals(comp(1, [item]), no_loader())

    assert res.total_weight_g == 200.0
    assert_in_delta res.nutrients.energy_kcal, 260.0, 0.0001
    assert_in_delta res.nutrients.protein_g, 5.0, 0.0001
  end

  test "household measures convert via grams_per_unit (2 colheres de sopa = 30 g)" do
    item = %ComponentItem{
      food: food(%{energy_kcal: 884.0, total_fat_g: 100.0}),
      food_id: 1,
      measure_unit: tbsp(),
      quantity: 2.0
    }

    res = Calculator.totals(comp(1, [item]), no_loader())

    assert_in_delta res.total_weight_g, 30.0, 0.0001
    assert_in_delta res.nutrients.energy_kcal, 265.2, 0.0001
  end

  test "a count unit without override contributes zero (weight unknown)" do
    item = %ComponentItem{
      food: food(%{energy_kcal: 143.0}),
      food_id: 1,
      measure_unit: counted(),
      quantity: 2.0
    }

    res = Calculator.totals(comp(1, [item]), no_loader())

    assert res.total_weight_g == 0.0
    assert res.nutrients.energy_kcal == 0.0
  end

  test "a count unit with override uses the override grams (2 un x 50 g = 100 g)" do
    item = %ComponentItem{
      food: food(%{energy_kcal: 143.0}),
      food_id: 1,
      measure_unit: counted(),
      quantity: 2.0,
      grams_per_unit_override: 50.0
    }

    res = Calculator.totals(comp(1, [item]), no_loader())

    assert_in_delta res.total_weight_g, 100.0, 0.0001
    assert_in_delta res.nutrients.energy_kcal, 143.0, 0.0001
  end

  test "a nested component contributes a mass fraction of its profile" do
    chicken = food(%{energy_kcal: 159.0, protein_g: 32.0})
    # child = 200 g chicken => 318 kcal / 64 g protein across 200 g
    child =
      comp(2, [%ComponentItem{food: chicken, food_id: 1, measure_unit: gram(), quantity: 200.0}])

    loader = fn 2 -> child end

    # parent takes 100 g of the child => half of everything
    parent =
      comp(1, [%ComponentItem{child_component_id: 2, measure_unit: gram(), quantity: 100.0}])

    res = Calculator.totals(parent, loader)

    assert_in_delta res.total_weight_g, 100.0, 0.0001
    assert_in_delta res.nutrients.energy_kcal, 159.0, 0.0001
    assert_in_delta res.nutrients.protein_g, 32.0, 0.0001
  end

  test "per_100g and per_serving derive from the totals" do
    item = %ComponentItem{
      food: food(%{energy_kcal: 130.0}),
      food_id: 1,
      measure_unit: gram(),
      quantity: 200.0
    }

    res = Calculator.totals(comp(1, [item]), no_loader())

    assert_in_delta Calculator.per_100g(res).energy_kcal, 130.0, 0.0001
    assert_in_delta Calculator.per_serving(res, 50.0).energy_kcal, 65.0, 0.0001
    assert Calculator.per_serving(res, nil) == nil
    assert Calculator.per_serving(res, 0) == nil
  end

  test "reference cycles are broken instead of looping forever" do
    food1 = food(%{energy_kcal: 100.0})

    # component 1 -> component 2 -> component 1 (cycle), plus a real food in 2
    child =
      comp(2, [
        %ComponentItem{child_component_id: 1, measure_unit: gram(), quantity: 50.0},
        %ComponentItem{food: food1, food_id: 1, measure_unit: gram(), quantity: 100.0}
      ])

    parent =
      comp(1, [%ComponentItem{child_component_id: 2, measure_unit: gram(), quantity: 100.0}])

    loader = fn
      1 -> parent
      2 -> child
    end

    res = Calculator.totals(parent, loader)
    # Terminates and yields a finite number rather than hanging.
    assert is_float(res.total_weight_g)
    assert res.total_weight_g >= 0.0
  end
end
