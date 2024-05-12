defmodule TextViewerWeb.LiveComponents.SectionContentComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id={"section-#{@id}"}>
      <p class="font-serif font-bold text-2xl text-center m-4"><%= @title %></p>
      <div class="flex flex-col">
        <%= for line <- @lines do %>
          <p class="font-serif text-xl leading-loose line-clamp-3 indent-10"><%= line %></p>
        <% end %>
      </div>
    </div>
    """
  end
end
