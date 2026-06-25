defmodule Kcal.Nutrition.Nutrients do
  @moduledoc """
  Value object representing a nutritional profile (an *absolute* set of
  nutrient amounts, not "per 100 g" — the basis is whatever produced it).

  All amounts are floats in the unit encoded by the field suffix
  (`_kcal`, `_g`, `_mg`). This module centralizes the canonical ordering of
  nutrients (Anvisa order) and the arithmetic used by the calculator so that
  summing and scaling profiles is consistent everywhere.
  """

  alias Kcal.Nutrition.Food

  @energy_field :energy_kcal

  # Canonical order — matches the strict Anvisa label order the UI must follow.
  @fields [
    :energy_kcal,
    :carbohydrate_g,
    :protein_g,
    :total_fat_g,
    :saturated_fat_g,
    :trans_fat_g,
    :fiber_g,
    :sodium_mg
  ]

  defstruct energy_kcal: 0.0,
            carbohydrate_g: 0.0,
            protein_g: 0.0,
            total_fat_g: 0.0,
            saturated_fat_g: 0.0,
            trans_fat_g: 0.0,
            fiber_g: 0.0,
            sodium_mg: 0.0

  @type t :: %__MODULE__{
          energy_kcal: float(),
          carbohydrate_g: float(),
          protein_g: float(),
          total_fat_g: float(),
          saturated_fat_g: float(),
          trans_fat_g: float(),
          fiber_g: float(),
          sodium_mg: float()
        }

  @doc "Canonical nutrient field order (Anvisa)."
  @spec fields() :: [atom()]
  def fields, do: @fields

  @doc "The field that carries energy (kcal)."
  @spec energy_field() :: atom()
  def energy_field, do: @energy_field

  @doc "A zeroed profile."
  @spec zero() :: t()
  def zero, do: %__MODULE__{}

  @doc "Builds a profile from a `Food`'s stored per-100 g values."
  @spec from_food(Food.t()) :: t()
  def from_food(%Food{} = food) do
    %__MODULE__{
      energy_kcal: nz(food.energy_kcal),
      carbohydrate_g: nz(food.carbohydrate_g),
      protein_g: nz(food.protein_g),
      total_fat_g: nz(food.total_fat_g),
      saturated_fat_g: nz(food.saturated_fat_g),
      trans_fat_g: nz(food.trans_fat_g),
      fiber_g: nz(food.fiber_g),
      sodium_mg: nz(food.sodium_mg)
    }
  end

  @doc "Field-wise sum of two profiles."
  @spec add(t(), t()) :: t()
  def add(%__MODULE__{} = a, %__MODULE__{} = b) do
    Enum.reduce(@fields, %__MODULE__{}, fn field, acc ->
      Map.put(acc, field, Map.fetch!(a, field) + Map.fetch!(b, field))
    end)
  end

  @doc "Multiplies every field by `factor`."
  @spec scale(t(), number()) :: t()
  def scale(%__MODULE__{} = n, factor) do
    Enum.reduce(@fields, %__MODULE__{}, fn field, acc ->
      Map.put(acc, field, Map.fetch!(n, field) * factor)
    end)
  end

  @doc "Sums a list of profiles."
  @spec sum([t()]) :: t()
  def sum(profiles), do: Enum.reduce(profiles, zero(), &add(&2, &1))

  defp nz(nil), do: 0.0
  defp nz(n) when is_integer(n), do: n * 1.0
  defp nz(n), do: n
end
