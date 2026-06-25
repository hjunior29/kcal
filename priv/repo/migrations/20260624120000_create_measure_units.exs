defmodule Kcal.Repo.Migrations.CreateMeasureUnits do
  use Ecto.Migration

  def change do
    create table(:measure_units) do
      add :name, :string, null: false
      add :abbreviation, :string, null: false
      add :grams_per_unit, :float
      add :kind, :string, null: false, default: "mass"
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:measure_units, [:abbreviation])
  end
end
