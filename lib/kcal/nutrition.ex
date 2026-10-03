defmodule Kcal.Nutrition do
  @moduledoc """
  The Nutrition context: strictly read-only queries for base foods and
  measure units from the scientific tables (TACO and TBCA), plus in-memory
  nutrient reporting.

  No user recipe is persisted to the database. The database is strictly read-only
  for reference tables.
  """

  import Ecto.Query, warn: false

  alias Kcal.Repo
  alias Kcal.Nutrition.{Calculator, Food, MeasureUnit}

  # --- Measure units (Read-only) -------------------------------------------

  @doc "All measure units, ordered for display."
  def list_measure_units do
    Repo.all(from u in MeasureUnit, order_by: [asc: u.position, asc: u.id])
  end

  def get_measure_unit!(id), do: Repo.get!(MeasureUnit, id)

  @doc "The unit used as the default when adding a new ingredient (grams)."
  def default_measure_unit do
    Repo.one(from u in MeasureUnit, where: u.abbreviation == "g", limit: 1) ||
      Repo.one(from u in MeasureUnit, order_by: [asc: u.position], limit: 1)
  end

  # --- Foods (Read-only) ---------------------------------------------------

  def get_food!(id), do: Repo.get!(Food, id)

  @doc "Fetches a food by id, or nil. Safe for client-supplied ids."
  def get_food(id), do: Repo.get(Food, id)

  @doc """
  Dynamic food search used by the live ingredient picker.
  Normalizes diacritics and case; empty term returns a small alphabetical sample.
  """
  def search_foods(term, limit \\ 25) do
    case normalize_search(term) do
      "" ->
        Repo.all(from f in Food, order_by: [asc: f.name], limit: ^limit)

      t ->
        pattern = "%#{escape_like(t)}%"
        prefix = "#{escape_like(t)}%"

        Repo.all(
          from f in Food,
            where: like(f.search_name, ^pattern),
            order_by: [
              asc: fragment("CASE WHEN search_name LIKE ? THEN 0 ELSE 1 END", ^prefix),
              asc: f.name
            ],
            limit: ^limit
        )
    end
  end

  # --- Reporting (Pure in-memory math) -------------------------------------

  @doc """
  Builds a full nutrient report from an in-memory recipe whose items have
  their `food` and `measure_unit` preloaded/attached.
  """
  def report_for(recipe) do
    result = Calculator.totals(recipe, fn _ -> nil end)

    %{
      result: result,
      per_100g: Calculator.per_100g(result),
      per_serving: Calculator.per_serving(result, recipe.serving_size_g)
    }
  end

  @doc "Normalizes text for search (lowercased, accents stripped, trimmed)."
  def normalize_search(nil), do: ""

  def normalize_search(term) when is_binary(term) do
    term
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.trim()
  end

  def normalize_search(_), do: ""

  defp escape_like(term), do: String.replace(term, ~r/([%_\\])/, "\\\\\\1")
end
