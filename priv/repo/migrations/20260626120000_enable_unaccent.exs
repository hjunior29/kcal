defmodule Kcal.Repo.Migrations.EnableUnaccent do
  use Ecto.Migration

  # `unaccent()` lets the ingredient search ignore diacritics, so "acucar"
  # matches "açúcar" and vice-versa (combined with ILIKE for case-insensitivity).
  def up, do: execute("CREATE EXTENSION IF NOT EXISTS unaccent")
  def down, do: execute("DROP EXTENSION IF EXISTS unaccent")
end
