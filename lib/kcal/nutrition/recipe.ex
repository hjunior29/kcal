defmodule Kcal.Nutrition.Recipe do
  @moduledoc """
  An in-memory representation of a recipe for the one-shot calculator.
  Never stored in the database.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string, default: ""
    field :description, :string, default: ""
    field :serving_size_g, :float
    field :servings_label, :string, default: ""
  end

  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name, :description, :serving_size_g, :servings_label])
    |> validate_number(:serving_size_g, greater_than: 0)
  end
end
