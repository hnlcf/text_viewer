defmodule TextViewerWeb.LiveComponents.SectionComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <section>
      <p class="font-serif font-bold text-2xl text-center m-4"><%= @title %></p>
      <%= for line <- @lines do %>
        <p class="font-serif text-xl leading-loose line-clamp-3 indent-10"><%= line %></p>
      <% end %>
    </section>
    """
  end
end
