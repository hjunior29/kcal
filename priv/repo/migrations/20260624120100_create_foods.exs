defmodule Kcal.Repo.Migrations.CreateFoods do
  use Ecto.Migration

  def change do
    create table(:foods) do
      add :name, :string, null: false
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

    # Fast prefix/substring search powered by trigram index (see search in context).
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"

    create index(:foods, [:name])
    create index(:foods, [:category])

    execute(
      "CREATE INDEX foods_name_trgm_idx ON foods USING gin (name gin_trgm_ops)",
      "DROP INDEX foods_name_trgm_idx"
    )
  end
end
