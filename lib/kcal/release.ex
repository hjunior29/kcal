defmodule Kcal.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix installed.
  """
  @app :kcal

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          if repo.aggregate(Kcal.Nutrition.Food, :count) > 0 do
            IO.puts("Database already seeded with reference foods. Skipping seed.")
          else
            seeds_file = Path.join(:code.priv_dir(@app), "repo/seeds.exs")

            if File.exists?(seeds_file) do
              IO.puts("Running seed script #{seeds_file}...")
              Code.eval_file(seeds_file)
            end
          end
        end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
