defmodule Kcal.Nutrition.MeasureUnit do
  @moduledoc """
  A unit of measure the user can pick when adding an ingredient to a component
  (g, ml, colher de sopa, colher de chá, unidade, ...).

  `grams_per_unit` is the *default* conversion to grams. Mass units convert
  exactly (g → 1.0, kg → 1000.0). Volume units assume water-like density
  (ml → 1.0) but can be overridden per item. Count units like "unidade" have
  no sensible global default (`grams_per_unit` is `nil`) and therefore require
  a per-item `grams_per_unit_override`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @kinds ~w(mass volume count)

  schema "measure_units" do
    field :name, :string
    field :abbreviation, :string
    field :grams_per_unit, :float
    field :kind, :string, default: "mass"
    field :position, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(measure_unit, attrs) do
    measure_unit
    |> cast(attrs, [:name, :abbreviation, :grams_per_unit, :kind, :position])
    |> validate_required([:name, :abbreviation, :kind])
    |> validate_inclusion(:kind, @kinds)
    |> validate_number(:grams_per_unit, greater_than: 0)
    |> unique_constraint(:abbreviation)
  end

  @doc "Valid measure unit kinds."
  def kinds, do: @kinds
end
