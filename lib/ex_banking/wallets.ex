defmodule ExBanking.Wallets do
  def start_link() do
    Registry.start_link(keys: :unique, name: ExBanking.Wallets)
  end

  def create_user(user) do
    case Registry.lookup(ExBanking.Wallets, user) do
      [] ->
        {:ok, _} = ExBanking.Wallet.start_link(user)
        :ok
      _ ->
        {:error, :user_already_exists}
    end
  end

  def lookup(user) do
    case Registry.lookup(ExBanking.Wallets, user) do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        {:error, :user_does_not_exist}
    end
  end
end
