defmodule Kcal.Nutrition.Component do
  @moduledoc """
  A user-created "Componente": a recipe/meal built from base foods and/or other
  components. Its nutritional profile is computed (never stored) by
  `Kcal.Nutrition.Calculator` from its `items`.

  `serving_size_g` (optional) is the portion size used for the "por porção"
  column of the Anvisa label. `servings_label` is the free-text household
  measure shown next to it (e.g. "1 fatia (60 g)").
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Kcal.Nutrition.ComponentItem

  @type t :: %__MODULE__{}

  schema "components" do
    field :name, :string
    field :search_name, :string
    field :description, :string
    field :serving_size_g, :float
    field :servings_label, :string

    has_many :items, ComponentItem,
      foreign_key: :component_id,
      preload_order: [asc: :position, asc: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :description, :serving_size_g, :servings_label])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_number(:serving_size_g, greater_than: 0)
    |> put_search_name()
    |> cast_assoc(:items,
      sort_param: :items_sort,
      drop_param: :items_drop,
      with: &ComponentItem.changeset/2
    )
  end

  defp put_search_name(changeset) do
    case get_change(changeset, :name) do
      nil ->
        case get_field(changeset, :name) do
          nil ->
            changeset

          name ->
            if get_field(changeset, :search_name) == nil do
              put_change(changeset, :search_name, Kcal.Nutrition.normalize_search(name))
            else
              changeset
            end
        end

      name ->
        put_change(changeset, :search_name, Kcal.Nutrition.normalize_search(name))
    end
  end
end
