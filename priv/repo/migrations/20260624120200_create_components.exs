defmodule Kcal.Repo.Migrations.CreateComponents do
  use Ecto.Migration

  def change do
    create table(:components) do
      add :name, :string, null: false
      add :search_name, :string
      add :description, :text
      add :serving_size_g, :float
      add :servings_label, :string

      timestamps(type: :utc_datetime)
    end

    create index(:components, [:name])
    create index(:components, [:search_name])
  end
end
