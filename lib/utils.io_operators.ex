defmodule Utils.IOOperators do
  def prompt(msg) do
    msg
    |> Kernel.<>(" ")
    |> IO.gets()
    |> String.slice(0..-2)
  end

  def prompt(:pwd, msg) do
    pwd = get_pwd(msg)
    String.slice(pwd, 0..-2)
  end

  def get_pwd(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets("#{prompt} ")

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    value
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt} ")
        loop(prompt)
    end
  end
end
