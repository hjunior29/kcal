defmodule KcalWeb.RedirectController do
  use KcalWeb, :controller

  def to_calculator(conn, _params) do
    redirect(conn, to: ~p"/calculadora")
  end
end
