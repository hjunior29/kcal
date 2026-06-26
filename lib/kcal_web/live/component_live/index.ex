defmodule KcalWeb.ComponentLive.Index do
  @moduledoc "Dashboard: lists every component the user has created."
  use KcalWeb, :live_view

  alias Kcal.Nutrition

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Componentes")
     |> assign(:query, "")
     |> load_rows("")}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:query, q) |> load_rows(q)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id |> Nutrition.get_component!() |> Nutrition.delete_component() do
      {:ok, _component} ->
        {:noreply,
         socket
         |> put_flash(:info, "Componente excluído.")
         |> load_rows(socket.assigns.query)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Este componente está sendo usado em outro e não pode ser excluído."
         )}
    end
  end

  defp load_rows(socket, query) do
    rows =
      case String.trim(query) do
        "" ->
          Nutrition.list_components()

        q ->
          ids = Nutrition.search_components(q) |> MapSet.new(& &1.id)
          Nutrition.list_components() |> Enum.filter(&MapSet.member?(ids, &1.component.id))
      end

    assign(socket, :rows, rows)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header_bar>
        <:title>Componentes</:title>
        <:subtitle>Receitas e refeições com cálculo nutricional</:subtitle>
        <:action>
          <.brutal_link navigate={~p"/components/new"} variant="solid">
            + Novo componente
          </.brutal_link>
        </:action>
      </.header_bar>

      <form phx-change="filter" class="mb-4">
        <input
          type="text"
          name="q"
          value={@query}
          placeholder="Filtrar componentes…"
          phx-debounce="150"
          autocomplete="off"
          class="w-full rounded-none border-2 border-black bg-white px-3 py-2 text-base focus:outline-none focus:ring-0 focus:border-black focus:bg-brand"
        />
      </form>

      <div :if={@rows == []} class="border-2 border-dashed border-black p-8 text-center">
        <p class="font-semibold">Nenhum componente ainda.</p>
        <p class="text-sm mt-1 opacity-70">
          Crie seu primeiro com o botão <span class="font-bold">+ Novo componente</span>.
        </p>
      </div>

      <table :if={@rows != []} class="w-full border-collapse border-2 border-black text-sm">
        <thead>
          <tr class="border-b-2 border-black bg-black text-white text-left">
            <th class="px-3 py-2 font-bold uppercase tracking-wide">Componente</th>
            <th class="px-3 py-2 font-bold uppercase tracking-wide w-24 text-center">Itens</th>
            <th class="px-3 py-2 font-bold uppercase tracking-wide w-40 text-right">Ações</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows} class="border-b border-black/30 hover:bg-brand">
            <td class="px-3 py-2">
              <.link
                navigate={~p"/components/#{row.component.id}"}
                class="font-semibold hover:underline"
              >
                {row.component.name}
              </.link>
              <p :if={row.component.description} class="text-xs opacity-60 truncate max-w-md">
                {row.component.description}
              </p>
            </td>
            <td class="px-3 py-2 text-center tabular-nums">{row.item_count}</td>
            <td class="px-3 py-2">
              <div class="flex gap-2 justify-end">
                <.brutal_link navigate={~p"/components/#{row.component.id}"}>Ver</.brutal_link>
                <.brutal_link navigate={~p"/components/#{row.component.id}/edit"}>
                  Editar
                </.brutal_link>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={row.component.id}
                  data-confirm="Excluir este componente?"
                  class="rounded-none border-2 border-black bg-white px-2 py-1 text-xs font-bold hover:bg-red-600 hover:text-white hover:border-red-600"
                >
                  Excluir
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
