defmodule TaiShangNftClient.CLI do
  @moduledoc """
  Documentation for `TaiShangNftClient`.
  """

  alias Utils.IOOperators
  @config_file_name "config.ini"
  @key_store_file_name "keys.store"
  @doc """
  Hello world.

  ## Examples

      iex> TaiShangNftClient.handle_opts([], ["import-priv"])
      :ok

  """
  def main(args) do
    {opts, words, _} =
      OptionParser.parse(args,
        strict: [
          help: nil,
          import_priv: nil,
          set_url: nil,
          get_nfts: :string,
          contract_addr: :string
          ],
        aliases: [
          h: :help,
          i: :import_priv,
          s: :set_url,
          g: :get_nfts,
          c: :contract_addr
          ])
    handle_opts(opts, words)
  end

  def handle_opts([import_priv: _whatever], []) do
    priv = IOOperators.prompt("Please Enter PrivKey:")
    pwd = IOOperators.prompt(:pwd, "Please Enter Password to Encrypt:")
    encrypted_priv_str =
      priv
      |> EthWallet.encrypt_key(pwd)
      |> Base.encode16(case: :lower)
    %{addr: addr, pub: pubkey} =
      priv
      |> String.replace("0x", "")
      |> Base.decode16!(case: :mixed)
      |> EthWallet.generate_keys()
    {:ok, payload_str} =
      Poison.encode(%{
          addr: addr,
          pub: Base.encode16(pubkey, case: :lower),
          priv_encrypted: encrypted_priv_str
      })
    File.write!(@key_store_file_name, payload_str)
  end

  def handle_opts([set_url: type], []) do
    endpoint = IOOperators.prompt("Please Set URL of #{type}:")
    payload =
      :json
      |> read(@config_file_name)
      |> Map.put(type, endpoint)
      |> Poison.encode!()
      |> Kernel.<>("\n")

    File.write!(@config_file_name, payload)
  end

  def handle_opts([get_nfts: type, contract_addr: c_addr], []) do
    endpoint = Map.get(read(:json, @config_file_name), type)
    get_nfts(type, endpoint, c_addr)
  end

  def handle_opts([help: _whatever], []) do
    IO.puts """
      1. --help(h): get the help of this client.
      2. --import_priv(i): import priv and save to key.store.
      3. --set_url(s): set url of eth/service side, example: --set_url eth / --set_url service
      4. --get_nfts(g) service --contract_addr: get nfts acccording to service, example: --get_nfts service --contract_addr 0x769699506f972A992fc8950C766F0C7256Df601f
      5. --get_nfts(g) eth --contract_addr: get nfts according to eth,example: --get_nfts eth --contract_addr 0x769699506f972A992fc8950C766F0C7256Df601f
    """
  end

  def get_nfts(type, nil, _c_addr, _addr), do: IO.puts("the url of '#{type}' is not set yet!Please use param: --set_url")
  def get_nfts("service", endpoint, c_addr)do
    keys = read(:json, @key_store_file_name)
    do_get_nfts(:service, endpoint, c_addr, keys)
  end

  def do_get_nfts(:service, endpoint, c_addr, %{"addr" => addr}) do

    endpoint
    |> build_url(c_addr, addr)
    |> ExHttp.get()
    |> handle_resp()
  end

  def handle_resp({:error, _}), do: :pass
  def handle_resp({:ok, %{"error_code" => 0, "result" => payload}}) do
    IO.puts inspect(payload, pretty: true)
  end

  def handle_resp({:ok, %{"error_code" => _others, "error_msg" => payload}}) do
    IO.puts inspect(payload, pretty: true)
  end
  def do_get_nfts(_, _, _endpoint), do: IO.puts "u are not import priv yet! Please use param: --import_priv"

  def build_url(endpoint, c_addr, addr) do
    "#{endpoint}?token_addr=#{c_addr}&addr=#{addr}"
  end
  def read(:json, path) do
    payload = File.read(path)
    case payload do
      {:error, :enoent} ->
        %{}
      {:ok, payload_str} ->
        Poison.decode!(payload_str)
    end
  end

end
