defmodule TextViewer.TextReader do
  def read(path) do
    lines =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim(&1))
      |> Enum.filter(fn line -> String.length(line) > 0 end)
      |> Enum.map(fn s ->
        if String.starts_with?(s, "===") do
          {:title, String.trim(s, "===")}
        else
          {:line, s}
        end
      end)

    lines
    |> Enum.reduce([], fn s, acc ->
      case s do
        {:title, title} ->
          [{:title, title, []} | acc]

        {:line, line} ->
          case acc do
            [] -> [{:title, "", [line]}]
            [{:title, title, lines} | tail] -> [{:title, title, [line | lines]} | tail]
          end
      end
    end)
    |> Enum.with_index()
    |> Enum.map(fn {{:title, title, lines}, index} ->
      %{id: index, title: title, lines: Enum.reverse(lines)}
    end)
    |> Enum.reverse()
  end
end
