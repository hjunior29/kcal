defmodule Kcal.Repo.Migrations.CreateComponents do
  use Ecto.Migration

  def change do
    create table(:components) do
      add :name, :string, null: false
      add :description, :text
      add :serving_size_g, :float
      add :servings_label, :string

      timestamps(type: :utc_datetime)
    end

    create index(:components, [:name])

    execute(
      "CREATE INDEX components_name_trgm_idx ON components USING gin (name gin_trgm_ops)",
      "DROP INDEX components_name_trgm_idx"
    )
  end
end
