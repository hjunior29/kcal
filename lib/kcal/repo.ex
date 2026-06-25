defmodule Kcal.Repo do
  use Ecto.Repo,
    otp_app: :kcal,
    adapter: Ecto.Adapters.Postgres
end
