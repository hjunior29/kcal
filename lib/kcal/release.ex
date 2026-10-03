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
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seeds_file = Path.join(:code.priv_dir(@app), "repo/seeds.exs")

          if File.exists?(seeds_file) do
            IO.puts("Running seed script #{seeds_file}...")
            Code.eval_file(seeds_file)
          end

          sample_file = Path.join(:code.priv_dir(@app), "repo/sample_components.exs")

          if File.exists?(sample_file) do
            IO.puts("Running sample components #{sample_file}...")
            Code.eval_file(sample_file)
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
