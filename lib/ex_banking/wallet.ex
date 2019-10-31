defmodule ExBanking.Wallet do
  @moduledoc """
  Wallet, supporting two stage deposits and withdrawals

  State consists of sub-wallets (by currency) and pending transactions.

  Sub-wallet stores commited balance and balances from pending deposits
  and withdrawals - these are used to ensure no transaction, capable of
  moving balance outside [0, @balance_cap] range cannot be initiated

  As checks are made on transaction start, commits are always successful
  """

  use GenServer

  @balance_cap 1_000_000_000_000
 
  def start_link(user) do
    GenServer.start_link(__MODULE__, user)
  end

  @doc """
  Start deposit tx
  """
  def deposit(id, amount, currency) do
    GenServer.call(id, {:deposit, amount, currency})
  end

  @doc """
  Start withdraw tx
  """
  def withdraw(id, amount, currency) do
    GenServer.call(id, {:withdraw, amount, currency})
  end

  @doc """
  Commit tx
  """
  def commit(id, txid) do
      GenServer.call(id, {:commit, txid})
  end

  @doc """
  Rollback tx
  """
  def rollback(id, txid) do
    GenServer.call(id, {:rollback, txid})
  end

  @doc """
  Get commited balance
  """
  def get_balance(id, currency) do
    GenServer.call(id, {:get_balance, currency})
  end

  @impl true
  def init(user) do
    case user do
      :null ->
        :ok
      _ ->
        {:ok, _} = Registry.register(ExBanking.Wallets, user, :nil)
    end
    {:ok, {%{}, %{}}}
  end

  @impl true
  def handle_call({op, amount, currency} = tx, _from, {wallets, txs} = state) when op in [:deposit, :withdraw] do
    wallet = Map.get(wallets, currency, %{balance: 0})
    balance = wallet[:balance]
    reserve = Map.get(wallet, op, 0)
    reserve_new = reserve + amount
    {valid, error} = case op do
      :deposit ->
        {balance + reserve_new < @balance_cap, :too_much_money}
      :withdraw ->
        {balance - reserve_new >= 0, :not_enough_money}
    end
    case valid do
      false ->
        {:reply, {:error, error}, state}
      true ->
        txid = make_ref()
        txs_new = Map.put(txs, txid, tx)
        wallet_new = Map.put(wallet, op, reserve_new)
        wallets_new = Map.put(wallets, currency, wallet_new)
        {:reply, {:ok, txid}, {wallets_new, txs_new}}
    end
  end

  def handle_call({op, txid}, _from, {wallets, txs} = state) when op in [:rollback, :commit] do
    case txs do
      %{^txid => {txop, amount, currency}} ->
        wallet = wallets[currency]
        reserve_new = wallet[txop] - amount
        balance_new = wallet[:balance] + case op do
          :rollback ->
            0
          :commit ->
            case txop do
              :deposit -> amount
              :withdraw -> -1 * amount
            end
        end
        wallet_new = %{ wallet | :balance => balance_new, txop => reserve_new }
        wallets_new = Map.put(wallets, currency, wallet_new)
        txs_new = Map.delete(txs, txid)
        {:reply, {:ok, balance_new}, {wallets_new, txs_new}}
      _ ->
        {:reply, {:error, :no_tx}, state}
    end
  end

  def handle_call({:get_balance, currency}, _from, {wallets, _} = state) do
    result = case wallets do
      %{^currency => %{:balance => balance}} ->
        balance
      _ ->
        0
    end
    {:reply, result, state}
  end
end
