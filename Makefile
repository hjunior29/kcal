# Kcal — atalhos de desenvolvimento
# Uso: `make` (ajuda), `make setup`, `make run`, etc.

.DEFAULT_GOAL := help
.PHONY: help setup deps run server iex \
        db.up db.create db.migrate db.reset db.seed sample \
        test test.watch check format format.check lint \
        assets.build assets.deploy precommit clean

# Container Postgres compartilhado (porta 5432) — não suba um segundo.
PG_CONTAINER ?= nutri-codex-postgres-1

## help: lista os alvos disponíveis
help:
	@echo "Kcal — alvos disponíveis:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'

# --- setup -----------------------------------------------------------------

## setup: instala deps, prepara assets, cria/migra o banco e roda o seed
setup: db.up
	mix setup

## deps: baixa as dependências do projeto
deps:
	mix deps.get

# --- run -------------------------------------------------------------------

## run: sobe o servidor Phoenix (http://localhost:4000)
run: db.up
	mix phx.server

## server: alias de `run`
server: run

## iex: sobe o servidor dentro de um IEx interativo
iex: db.up
	iex -S mix phx.server

# --- banco de dados --------------------------------------------------------

## db.up: garante que o container Postgres compartilhado está rodando
db.up:
	@docker start $(PG_CONTAINER) >/dev/null 2>&1 || true

## db.create: cria os bancos (dev/test)
db.create: db.up
	mix ecto.create

## db.migrate: aplica as migrations pendentes
db.migrate: db.up
	mix ecto.migrate

## db.seed: popula alimentos TACO/TBCA e unidades de medida
db.seed: db.up
	mix run priv/repo/seeds.exs

## sample: insere componentes de exemplo (Marmita aninhada etc.)
sample: db.up
	mix run priv/repo/sample_components.exs

## db.reset: derruba, recria, migra e roda o seed do zero
db.reset: db.up
	mix ecto.reset

# --- testes & qualidade ----------------------------------------------------

## test: roda a suíte de testes
test: db.up
	mix test

## check: compila com warnings-as-errors, format e testes (igual ao pre-commit)
check: db.up
	mix precommit

## format: formata o código
format:
	mix format

## format.check: verifica formatação sem alterar arquivos
format.check:
	mix format --check-formatted

# --- assets ----------------------------------------------------------------

## assets.build: compila Tailwind + esbuild
assets.build:
	mix assets.build

## assets.deploy: build minificado + digest (produção)
assets.deploy:
	mix assets.deploy

# --- limpeza ---------------------------------------------------------------

## clean: remove artefatos de build
clean:
	mix clean
	rm -rf _build deps
