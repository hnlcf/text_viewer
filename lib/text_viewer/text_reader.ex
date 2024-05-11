defmodule TextViewer.TextReader do
  @type split_mode :: :start_with_equal | :split_by_dash

  @spec read(String.t(), split_mode) :: [map()]
  def read(path, split_mode) do
    contents =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim(&1))
      |> Enum.filter(fn line -> String.length(line) > 0 end)

    lines =
      case split_mode do
        :start_with_equal ->
          contents
          |> Enum.map(fn s ->
            if String.starts_with?(s, "===") do
              {:title, String.trim(s, "===")}
            else
              {:line, s}
            end
          end)

        :split_by_dash ->
          {_, data} =
            contents
            |> Enum.reduce({:line, []}, fn s, {state, acc} ->
              case state do
                :line ->
                  if String.starts_with?(s, "---") do
                    {:title, acc}
                  else
                    {:line, [{:line, s} | acc]}
                  end

                :title ->
                  if String.starts_with?(s, "---") do
                    {:line, acc}
                  else
                    {:line, [{:title, s} | acc]}
                  end
              end
            end)

          data |> Enum.reverse()
      end

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
