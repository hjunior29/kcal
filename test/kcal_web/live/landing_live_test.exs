defmodule KcalWeb.LandingLiveTest do
  use KcalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "landing page displays scientific sources and one-shot philosophy", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Rotulagem Nutricional Anvisa"
    assert html =~ "Transparente &amp; One-Shot" or html =~ "Transparente & One-Shot"
    assert html =~ "Tabela TACO (NEPA / UNICAMP)"
    assert html =~ "Tabela TBCA (USP / FoRC)"
    assert html =~ "Abrir Calculadora One-Shot"
  end

  test "legacy /components redirect to /calculadora", %{conn: conn} do
    conn = get(conn, "/components")
    assert redirected_to(conn) == "/calculadora"

    conn = get(conn, "/components/1")
    assert redirected_to(conn) == "/calculadora"
  end
end
