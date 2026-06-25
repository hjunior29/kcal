defmodule Kcal.Repo.Migrations.CreateComponentItems do
  use Ecto.Migration

  def change do
    create table(:component_items) do
      add :quantity, :float, null: false, default: 100.0
      add :grams_per_unit_override, :float
      add :position, :integer, null: false, default: 0

      add :component_id, references(:components, on_delete: :delete_all), null: false
      add :food_id, references(:foods, on_delete: :restrict)
      add :child_component_id, references(:components, on_delete: :restrict)
      add :measure_unit_id, references(:measure_units, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:component_items, [:component_id])
    create index(:component_items, [:food_id])
    create index(:component_items, [:child_component_id])
    create index(:component_items, [:measure_unit_id])

    # A line references a base food XOR a nested component — exactly one.
    create constraint(:component_items, :component_items_food_xor_component,
             check: "(food_id IS NULL) <> (child_component_id IS NULL)"
           )

    # A component can never directly contain itself.
    create constraint(:component_items, :component_items_no_self_reference,
             check: "child_component_id IS NULL OR child_component_id <> component_id"
           )
  end
end
