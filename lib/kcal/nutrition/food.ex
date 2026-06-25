defmodule Kcal.Nutrition.Food do
  @moduledoc """
  A base food from a public composition table (TACO / TBCA).

  All nutrient values are stored **per 100 g of edible portion**, which is the
  reference basis used by both TACO and TBCA. The calculator scales these to
  the actual grams used in a component item.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @sources ~w(TACO TBCA OUTRO)

  schema "foods" do
    field :name, :string
    field :category, :string
    field :source, :string, default: "TACO"
    # External reference code in the source table (e.g. TACO id), for traceability.
    field :source_code, :string

    # Nutrients per 100 g.
    field :energy_kcal, :float, default: 0.0
    field :carbohydrate_g, :float, default: 0.0
    field :protein_g, :float, default: 0.0
    field :total_fat_g, :float, default: 0.0
    field :saturated_fat_g, :float, default: 0.0
    field :trans_fat_g, :float, default: 0.0
    field :fiber_g, :float, default: 0.0
    field :sodium_mg, :float, default: 0.0

    timestamps(type: :utc_datetime)
  end

  @nutrient_fields [
    :energy_kcal,
    :carbohydrate_g,
    :protein_g,
    :total_fat_g,
    :saturated_fat_g,
    :trans_fat_g,
    :fiber_g,
    :sodium_mg
  ]

  @doc false
  def changeset(food, attrs) do
    food
    |> cast(attrs, [:name, :category, :source, :source_code | @nutrient_fields])
    |> validate_required([:name, :source])
    |> validate_inclusion(:source, @sources)
    |> validate_nutrients_non_negative()
  end

  defp validate_nutrients_non_negative(changeset) do
    Enum.reduce(@nutrient_fields, changeset, fn field, cs ->
      validate_number(cs, field, greater_than_or_equal_to: 0)
    end)
  end

  def sources, do: @sources
  def nutrient_fields, do: @nutrient_fields
end
