defmodule Kcal.Nutrition.ComponentItem do
  @moduledoc """
  A single line of a component. It references EITHER a base `food` OR another
  `child_component` (nesting / composition) — exactly one of the two. The
  amount is expressed as `quantity` of a `measure_unit`; `grams_per_unit_override`
  lets a line pin the gram-equivalent of one unit (required for "unidade",
  optional for volume units whose density differs from water).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Kcal.Nutrition.{Component, Food, MeasureUnit}

  @type t :: %__MODULE__{}

  schema "component_items" do
    field :quantity, :float, default: 100.0
    field :grams_per_unit_override, :float
    field :position, :integer, default: 0

    belongs_to :component, Component
    belongs_to :food, Food
    belongs_to :child_component, Component
    belongs_to :measure_unit, MeasureUnit

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :quantity,
      :grams_per_unit_override,
      :position,
      :food_id,
      :child_component_id,
      :measure_unit_id
    ])
    |> validate_required([:quantity, :measure_unit_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:grams_per_unit_override, greater_than: 0)
    |> validate_exactly_one_reference()
    |> assoc_constraint(:food)
    |> assoc_constraint(:child_component)
    |> assoc_constraint(:measure_unit)
    |> check_constraint(:child_component_id,
      name: :component_items_no_self_reference,
      message: "um componente não pode conter a si mesmo"
    )
    |> check_constraint(:food_id,
      name: :component_items_food_xor_component,
      message: "selecione um alimento OU um componente"
    )
  end

  # A line points at a base food XOR a nested component, never both, never neither.
  defp validate_exactly_one_reference(changeset) do
    food_id = get_field(changeset, :food_id)
    child_id = get_field(changeset, :child_component_id)

    case {food_id, child_id} do
      {nil, nil} ->
        add_error(changeset, :food_id, "selecione um alimento ou um componente")

      {f, c} when not is_nil(f) and not is_nil(c) ->
        add_error(changeset, :child_component_id, "selecione apenas alimento OU componente")

      _ ->
        changeset
    end
  end
end
