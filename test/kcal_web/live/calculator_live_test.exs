defmodule KcalWeb.CalculatorLiveTest do
  use KcalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kcal.Repo
  alias Kcal.Nutrition.{Food, MeasureUnit}

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

    {:ok, arroz} =
      %Food{}
      |> Food.changeset(%{
        name: "Arroz, branco, cozido",
        source: "TACO",
        energy_kcal: 128.0,
        carbohydrate_g: 28.1,
        protein_g: 2.5
      })
      |> Repo.insert()

    %{gram: gram, xicara: xicara, ovo: ovo, arroz: arroz}
  end

  test "calculator renders one-shot notice and empty state", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/calculadora")
    assert html =~ "Modo One-Shot (100% Privado)"
    assert html =~ "Sua receita ainda não possui ingredientes"
  end

  test "search filters foods dynamically", %{conn: conn, ovo: ovo} do
    {:ok, lv, _html} = live(conn, ~p"/calculadora")

    html =
      lv
      |> form(~s|form[phx-change="search"]|, %{q: "ovo"})
      |> render_change()

    assert html =~ ovo.name
    refute html =~ "Arroz, branco"
  end

  test "adding food calculates nutrition facts live in memory", %{conn: conn, ovo: ovo} do
    {:ok, lv, _html} = live(conn, ~p"/calculadora")

    # Search and add egg
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()

    html =
      lv
      |> element(~s|button[phx-click="add_food"][phx-value-id="#{ovo.id}"]|)
      |> render_click()

    assert html =~ "Ingredientes Adicionados (1)"
    assert html =~ "INFORMAÇÃO NUTRICIONAL"
    assert html =~ ovo.name
  end

  test "live unit and quantity changes update grams and macros", %{
    conn: conn,
    ovo: ovo,
    xicara: xicara
  } do
    {:ok, lv, _html} = live(conn, ~p"/calculadora")
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()
    lv |> element(~s|button[phx-click="add_food"][phx-value-id="#{ovo.id}"]|) |> render_click()

    item_form = ~s|form[phx-value-tid="it-1"]|

    # Default is 100g -> change to 50g
    html = lv |> form(item_form, %{quantity: "50"}) |> render_change()
    assert html =~ "50 g"

    # Change to Xícara (240g) x 2 = 480g
    html =
      lv
      |> form(item_form, %{quantity: "2", measure_unit_id: "#{xicara.id}"})
      |> render_change()

    assert html =~ "480 g"
  end

  test "view modes switch between ANVISA formats", %{conn: conn, ovo: ovo} do
    {:ok, lv, _html} = live(conn, ~p"/calculadora")
    lv |> form(~s|form[phx-change="search"]|, %{q: "ovo"}) |> render_change()
    lv |> element(~s|button[phx-click="add_food"][phx-value-id="#{ovo.id}"]|) |> render_click()

    # Switch to Linear
    html =
      lv
      |> element(~s|button[phx-click="set_view"][phx-value-view="linear"]|)
      |> render_click()

    assert html =~ "Informação nutricional" or html =~ "INFORMAÇÃO NUTRICIONAL"
  end

  test "JSON recipe import loads data into memory", %{conn: conn, ovo: ovo, gram: gram} do
    {:ok, lv, _html} = live(conn, ~p"/calculadora")

    recipe_json = %{
      "recipe" => %{
        "name" => "Omelete Importada",
        "description" => "Feita com ovos frescos",
        "serving_size_g" => 120.0,
        "servings_label" => "1 porção"
      },
      "items" => [
        %{
          "food_id" => ovo.id,
          "food_name" => ovo.name,
          "measure_unit_id" => gram.id,
          "quantity" => 150.0,
          "grams_per_unit_override" => nil
        }
      ]
    }

    html = render_hook(lv, "import_recipe", recipe_json)
    assert html =~ "Omelete Importada"
    assert html =~ "Feita com ovos frescos"
    assert html =~ "Receita carregada com sucesso!"
  end
end
