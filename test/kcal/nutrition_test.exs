defmodule Kcal.NutritionTest do
  @moduledoc "Context-level tests: deletion safety with nesting, and cycle rejection."
  use Kcal.DataCase, async: true

  alias Kcal.Nutrition
  alias Kcal.Nutrition.{Component, Food, MeasureUnit}

  setup do
    {:ok, gram} =
      %MeasureUnit{}
      |> MeasureUnit.changeset(%{
        name: "Grama",
        abbreviation: "g",
        grams_per_unit: 1.0,
        kind: "mass"
      })
      |> Repo.insert()

    {:ok, rice} =
      %Food{}
      |> Food.changeset(%{name: "Arroz", source: "TACO", energy_kcal: 128.0})
      |> Repo.insert()

    %{gram: gram, rice: rice}
  end

  defp with_food(name, food, gram, qty \\ 100.0) do
    %{
      "name" => name,
      "items" => [%{"food_id" => food.id, "measure_unit_id" => gram.id, "quantity" => qty}]
    }
  end

  defp with_child(name, child, gram, qty \\ 50.0) do
    %{
      "name" => name,
      "items" => [
        %{"child_component_id" => child.id, "measure_unit_id" => gram.id, "quantity" => qty}
      ]
    }
  end

  test "delete_component/1 returns {:error, _} (no crash) when nested in another", %{
    gram: g,
    rice: rice
  } do
    {:ok, child} = Nutrition.create_component(with_food("Filho", rice, g))
    {:ok, _parent} = Nutrition.create_component(with_child("Pai", child, g))

    assert {:error, %Ecto.Changeset{}} = Nutrition.delete_component(child)
    assert Repo.get(Component, child.id), "o componente aninhado não deve ser removido"
  end

  test "delete_component/1 returns {:ok, _} for a free component", %{gram: g, rice: rice} do
    {:ok, free} = Nutrition.create_component(with_food("Livre", rice, g))

    assert {:ok, _} = Nutrition.delete_component(free)
    refute Repo.get(Component, free.id)
  end

  test "update_component/2 rejects an indirect cycle (A → B → A)", %{gram: g, rice: rice} do
    {:ok, a} = Nutrition.create_component(with_food("Receita A", rice, g))
    {:ok, b} = Nutrition.create_component(with_child("Receita B", a, g))

    a = Nutrition.get_component!(a.id)

    assert {:error, changeset} =
             Nutrition.update_component(a, with_child("Receita A", b, g))

    assert changeset.errors[:items]
  end

  test "create_component/1 persists nested items and computes a report", %{gram: g, rice: rice} do
    {:ok, child} = Nutrition.create_component(with_food("Filho", rice, g, 200.0))
    {:ok, parent} = Nutrition.create_component(with_child("Pai", child, g, 100.0))

    report = Nutrition.component_report(parent)
    # half of (200 g rice @128 kcal/100g = 256 kcal) => 128 kcal over 100 g
    assert_in_delta report.result.total_weight_g, 100.0, 0.001
    assert_in_delta report.result.nutrients.energy_kcal, 128.0, 0.001
  end
end
