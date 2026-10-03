defmodule Kcal.Repo.Migrations.CreateFoods do
  use Ecto.Migration

  def change do
    create table(:foods) do
      add :name, :string, null: false
      add :search_name, :string
      add :category, :string
      add :source, :string, null: false, default: "TACO"
      add :source_code, :string

      add :energy_kcal, :float, null: false, default: 0.0
      add :carbohydrate_g, :float, null: false, default: 0.0
      add :protein_g, :float, null: false, default: 0.0
      add :total_fat_g, :float, null: false, default: 0.0
      add :saturated_fat_g, :float, null: false, default: 0.0
      add :trans_fat_g, :float, null: false, default: 0.0
      add :fiber_g, :float, null: false, default: 0.0
      add :sodium_mg, :float, null: false, default: 0.0

      timestamps(type: :utc_datetime)
    end

    create index(:foods, [:name])
    create index(:foods, [:search_name])
    create index(:foods, [:category])
  end
end
