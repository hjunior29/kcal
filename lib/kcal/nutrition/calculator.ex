defmodule Kcal.Nutrition.Calculator do
  @moduledoc """
  Pure nutritional math for components.

  Every line is reduced to **grams** and then to an absolute `Nutrients` profile:

    * base food  → `per-100 g profile × (grams / 100)`
    * nested component → child's absolute profile × `(grams / child_total_weight)`,
      i.e. we take a *mass fraction* of the child recipe.

  The whole component's profile is the sum of its lines; its total weight is the
  sum of line grams. From there `per_100g/1` and `per_serving/2` derive the two
  Anvisa columns.

  Recursion is driven by a `loader` (`component_id -> Component` with `items`,
  `food`, `measure_unit` and `child_component` preloaded), so the module stays
  free of `Repo`. A `visited` set breaks reference cycles defensively.
  """

  alias Kcal.Nutrition.{ComponentItem, Food, Nutrients}

  defmodule Result do
    @moduledoc "Computed totals for a component, plus a per-line breakdown."
    defstruct total_weight_g: 0.0, nutrients: %Nutrients{}, lines: []

    @type line :: %{
            item: ComponentItem.t(),
            label: String.t(),
            grams: float(),
            nutrients: Nutrients.t()
          }
    @type t :: %__MODULE__{
            total_weight_g: float(),
            nutrients: Nutrients.t(),
            lines: [line()]
          }
  end

  @doc """
  Computes absolute totals for `component`. `loader` resolves a nested component
  by id to a struct with `items` (and their `food`/`measure_unit`/`child_component`)
  preloaded.
  """
  @spec totals(map(), (integer() -> map() | nil)) :: Result.t()
  def totals(component, loader \\ fn _ -> nil end)

  def totals(%{items: _} = component, loader) when is_function(loader, 1) do
    component_id = Map.get(component, :id)
    visited = if component_id, do: MapSet.new([component_id]), else: MapSet.new()
    do_totals(component, loader, visited)
  end

  @doc """
  Grams contributed by a single line: `quantity × grams_per_unit`, where the
  per-unit grams come from a line override or the measure unit's default.
  Returns `0.0` when neither is known (e.g. "unidade" without an override).
  """
  @spec item_grams(map()) :: float()
  def item_grams(%{quantity: q} = item) do
    case grams_per_unit(item) do
      nil -> 0.0
      gpu -> (q || 0.0) * gpu
    end
  end

  def item_grams(_), do: 0.0

  @doc "The two Anvisa columns + the raw totals, ready for display."
  @spec per_100g(Result.t()) :: Nutrients.t()
  def per_100g(%Result{total_weight_g: w, nutrients: n}) when w > 0,
    do: Nutrients.scale(n, 100.0 / w)

  def per_100g(%Result{}), do: Nutrients.zero()

  @doc "Profile for a portion of `serving_g` grams, or `nil` if it can't be derived."
  @spec per_serving(Result.t(), number() | nil) :: Nutrients.t() | nil
  def per_serving(%Result{total_weight_g: w, nutrients: n}, serving_g)
      when is_number(serving_g) and serving_g > 0 and w > 0,
      do: Nutrients.scale(n, serving_g / w)

  def per_serving(%Result{}, _serving_g), do: nil

  # --- internals -----------------------------------------------------------

  defp do_totals(%{items: items}, loader, visited) do
    lines = Enum.map(items, &line(&1, loader, visited))

    %Result{
      total_weight_g: Enum.reduce(lines, 0.0, fn l, acc -> acc + l.grams end),
      nutrients: Nutrients.sum(Enum.map(lines, & &1.nutrients)),
      lines: lines
    }
  end

  defp line(item, loader, visited) do
    {grams, nutrients} = contribution(item, loader, visited)
    %{item: item, label: label(item), grams: grams, nutrients: nutrients}
  end

  # Base food: grams always count (even zero-calorie mass like water or salt).
  defp contribution(%{food: %Food{} = food} = item, _loader, _visited) do
    grams = item_grams(item)
    {grams, Nutrients.from_food(food) |> Nutrients.scale(grams / 100.0)}
  end

  # Nested component: the line's grams count ONLY when the child resolves to real
  # mass, so weight and nutrients never disagree. A cycle, a missing child, or an
  # empty child contributes neither grams nor nutrients.
  defp contribution(%{child_component_id: child_id} = item, loader, visited)
       when not is_nil(child_id) do
    grams = item_grams(item)

    cond do
      MapSet.member?(visited, child_id) ->
        {0.0, Nutrients.zero()}

      child = loader.(child_id) ->
        child_result = do_totals(child, loader, MapSet.put(visited, child_id))

        if child_result.total_weight_g > 0 do
          {grams, Nutrients.scale(child_result.nutrients, grams / child_result.total_weight_g)}
        else
          {0.0, Nutrients.zero()}
        end

      true ->
        {0.0, Nutrients.zero()}
    end
  end

  defp contribution(_item, _loader, _visited), do: {0.0, Nutrients.zero()}

  defp grams_per_unit(%{grams_per_unit_override: gpu}) when is_number(gpu), do: gpu

  defp grams_per_unit(%{measure_unit: %{grams_per_unit: gpu}}) when is_number(gpu),
    do: gpu

  defp grams_per_unit(_item), do: nil

  defp label(%{food: %{name: name}}), do: name
  defp label(%{child_component: %{name: name}}), do: name
  defp label(_item), do: "—"
end
