defmodule KcalWeb.ComponentLiveTest do
  use KcalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kcal.Repo
  alias Kcal.Nutrition.{Component, Food, MeasureUnit}

  setup do
    {:ok, gram} =
      %MeasureUnit{}
      |> MeasureUnit.changeset(%{
        name: "Grama",
        abbreviation: "g",
        grams_per_unit: 1.0,
        kind: "mass",
        position: 0
      })
      |> Repo.insert()

    {:ok, ovo} =
      %Food{}
      |> Food.changeset(%{
        name: "Ovo de galinha, inteiro, cru",
        source: "TACO",
        category: "Ovos",
        energy_kcal: 143.0,
        carbohydrate_g: 1.6,
        protein_g: 13.0,
        total_fat_g: 8.9,
        saturated_fat_g: 2.7,
        sodium_mg: 140.0
      })
      |> Repo.insert()

    {:ok, _arroz} =
      %Food{}
      |> Food.changeset(%{
        name: "Arroz, branco, cozido",
        source: "TACO",
        energy_kcal: 128.0,
        carbohydrate_g: 28.1,
        protein_g: 2.5
      })
      |> Repo.insert()

    %{gram: gram, ovo: ovo}
  end

  test "dashboard shows the empty state when there are no components", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")
    assert html =~ "Nenhum componente"
  end

  test "builder: dynamic search filters the food base", %{conn: conn, ovo: ovo} do
    {:ok, lv, _html} = live(conn, ~p"/components/new")

    html =
      lv
      |> form(~s|form[phx-change="search"]|, %{q: "ovo"})
      |> render_change()

    assert html =~ ovo.name
    refute html =~ "Arroz, branco"
  end

  test "builder: search, add a food and save creates a persisted component", %{
    conn: conn,
    ovo: ovo
  } do
    {:ok, lv, _html} = live(conn, ~p"/components/new")

    # search then add the egg
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()

    html =
      lv
      |> element(~s|button[phx-value-kind="food"][phx-value-id="#{ovo.id}"]|)
      |> render_click()

    assert html =~ "Itens do componente (1)"

    # name it and save
    result =
      lv
      |> form("#component-form", component: %{name: "Omelete simples", serving_size_g: "120"})
      |> render_submit()

    assert {:ok, _show_lv, show_html} = follow_redirect(result, conn)
    assert show_html =~ "Omelete simples"
    assert show_html =~ "INFORMAÇÃO NUTRICIONAL"

    component = Repo.get_by!(Component, name: "Omelete simples") |> Repo.preload(:items)
    assert component.serving_size_g == 120.0
    assert length(component.items) == 1
    assert hd(component.items).food_id == ovo.id
  end

  test "builder: the '= g' updates live when quantity or measure changes", %{
    conn: conn,
    ovo: ovo
  } do
    {:ok, xicara} =
      %MeasureUnit{}
      |> MeasureUnit.changeset(%{
        name: "Xícara",
        abbreviation: "xíc",
        grams_per_unit: 240.0,
        kind: "volume",
        position: 6
      })
      |> Repo.insert()

    {:ok, lv, _html} = live(conn, ~p"/components/new")
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()
    lv |> element(~s|button[phx-value-kind="food"][phx-value-id="#{ovo.id}"]|) |> render_click()

    # The first added item gets temp_id "new-1" and defaults to 100 g (Grama).
    item_form = ~s|form[phx-value-tid="new-1"]|

    # Change quantity → grams must follow (100 → 5 g at 1 g/un).
    html = lv |> form(item_form, %{quantity: "5"}) |> render_change()
    assert html =~ "5 g"

    # Change measure to Xícara (240 g) with quantity 2 → 480 g.
    html =
      lv
      |> form(item_form, %{quantity: "2", measure_unit_id: "#{xicara.id}"})
      |> render_change()

    assert html =~ "480 g"
  end

  test "builder: a created component then appears on the dashboard", %{conn: conn, ovo: ovo} do
    {:ok, lv, _html} = live(conn, ~p"/components/new")
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()
    lv |> element(~s|button[phx-value-kind="food"][phx-value-id="#{ovo.id}"]|) |> render_click()

    lv
    |> form("#component-form", component: %{name: "Omelete simples"})
    |> render_submit()

    {:ok, _index, html} = live(conn, ~p"/")
    assert html =~ "Omelete simples"
  end
end
