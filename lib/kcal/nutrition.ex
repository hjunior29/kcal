defmodule Kcal.Nutrition do
  @moduledoc """
  The Nutrition context: the public API for base foods, measure units and
  user-built components, plus nutrient reporting.

  This is the only module the web layer should talk to.
  """

  import Ecto.Query, warn: false

  alias Kcal.Repo
  alias Kcal.Nutrition.{Calculator, Component, Food, MeasureUnit}

  @item_preloads [items: [:food, :measure_unit, :child_component]]

  # --- Measure units -------------------------------------------------------

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

  # --- Foods ---------------------------------------------------------------

  def get_food!(id), do: Repo.get!(Food, id)

  @doc "Fetches a food by id, or nil. Safe for client-supplied ids."
  def get_food(id), do: Repo.get(Food, id)

  @doc """
  Dynamic, trigram-ranked food search used by the live ingredient picker.
  Empty term returns a small alphabetical sample so the list is never blank.
  """
  def search_foods(term, limit \\ 20) do
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

  # --- Components ----------------------------------------------------------

  @doc "Dashboard listing: components with a precomputed item count."
  def list_components do
    item_counts =
      from i in "component_items",
        group_by: i.component_id,
        select: %{component_id: i.component_id, count: count(i.id)}

    Repo.all(
      from c in Component,
        left_join: ic in subquery(item_counts),
        on: ic.component_id == c.id,
        order_by: [desc: c.updated_at],
        select: %{component: c, item_count: coalesce(ic.count, 0)}
    )
  end

  @doc """
  Dynamic search over previously-created components, for nesting one component
  inside another. `exclude_id` keeps a component from offering itself.
  """
  def search_components(term, exclude_id \\ nil, limit \\ 20) do
    base = from c in Component, limit: ^limit
    base = if exclude_id, do: from(c in base, where: c.id != ^exclude_id), else: base

    case normalize_search(term) do
      "" ->
        Repo.all(from c in base, order_by: [desc: c.updated_at])

      t ->
        pattern = "%#{escape_like(t)}%"
        prefix = "#{escape_like(t)}%"

        Repo.all(
          from c in base,
            where: like(c.search_name, ^pattern),
            order_by: [
              asc: fragment("CASE WHEN search_name LIKE ? THEN 0 ELSE 1 END", ^prefix),
              asc: c.name
            ]
        )
    end
  end

  @doc "Loads a component with its items + each item's food/measure_unit/child_component."
  def get_component!(id), do: Repo.get!(Component, id) |> Repo.preload(@item_preloads)

  @doc "Fetches a component by id, or nil. Safe for client-supplied ids."
  def get_component(id), do: Repo.get(Component, id)

  @doc "A blank component for the new-form."
  def new_component, do: %Component{items: []}

  def change_component(%Component{} = component, attrs \\ %{}) do
    Component.changeset(component, attrs)
  end

  def create_component(attrs) do
    %Component{}
    |> Component.changeset(attrs)
    |> Repo.insert()
  end

  def update_component(%Component{} = component, attrs) do
    component
    |> Component.changeset(attrs)
    |> reject_cycles(component.id)
    |> Repo.update()
  end

  def delete_component(%Component{} = component) do
    if is_used_as_child?(component.id) do
      changeset =
        component
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(
          :child_component_id,
          "este componente está sendo usado em outro e não pode ser excluído"
        )

      {:error, changeset}
    else
      Repo.delete(component)
    end
  end

  defp is_used_as_child?(component_id) do
    Repo.exists?(from i in "component_items", where: i.child_component_id == ^component_id)
  end

  # --- Reporting -----------------------------------------------------------

  @doc """
  Full nutrient report for a persisted component: raw `Calculator.Result`, the
  per-100 g profile and the per-serving profile (nil if no serving size is set).
  """
  def component_report(%Component{id: id} = component) when not is_nil(id) do
    node = load_node(id) || Repo.preload(component, @item_preloads)
    report_for(node)
  end

  def component_report(%Component{} = component), do: report_for(component)

  @doc """
  Builds a report from a component whose `items` are already loaded (each with
  `food`/`measure_unit`/`child_component`). Used for the live builder preview,
  where the component isn't persisted yet. Nested children are still resolved
  from the database via `load_node/1`.
  """
  def report_for(%Component{} = component) do
    result = Calculator.totals(component, &load_node/1)

    %{
      result: result,
      per_100g: Calculator.per_100g(result),
      per_serving: Calculator.per_serving(result, component.serving_size_g)
    }
  end

  @doc "Calculator loader: a component (with one preloaded level) by id, or nil."
  def load_node(id) do
    case Repo.get(Component, id) do
      nil -> nil
      component -> Repo.preload(component, @item_preloads)
    end
  end

  # --- internals -----------------------------------------------------------

  # Rejects an update that would make a component contain itself transitively
  # (A → B → A). Direct self-reference is also caught by a DB check constraint.
  defp reject_cycles(%Ecto.Changeset{valid?: true} = changeset, nil), do: changeset

  defp reject_cycles(%Ecto.Changeset{valid?: true} = changeset, component_id) do
    child_ids =
      changeset
      |> Ecto.Changeset.get_field(:items, [])
      |> Enum.map(& &1.child_component_id)
      |> Enum.reject(&is_nil/1)

    if Enum.any?(child_ids, &(&1 == component_id or descendant?(component_id, &1))) do
      Ecto.Changeset.add_error(
        changeset,
        :items,
        "aninhamento inválido: criaria um ciclo entre componentes"
      )
    else
      changeset
    end
  end

  defp reject_cycles(changeset, _component_id), do: changeset

  # Is `target` reachable as a descendant of `root` (following child_component links)?
  defp descendant?(target, root), do: do_descendant?(target, [root], MapSet.new())

  defp do_descendant?(_target, [], _seen), do: false

  defp do_descendant?(target, [current | rest], seen) do
    cond do
      MapSet.member?(seen, current) ->
        do_descendant?(target, rest, seen)

      true ->
        children =
          Repo.all(
            from i in "component_items",
              where: i.component_id == ^current and not is_nil(i.child_component_id),
              select: i.child_component_id
          )

        if target in children do
          true
        else
          do_descendant?(target, rest ++ children, MapSet.put(seen, current))
        end
    end
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
