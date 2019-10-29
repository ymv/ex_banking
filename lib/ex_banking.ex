defmodule ExBanking do
  @moduledoc """
  Documentation for ExBanking.
  """

  use GenServer

  @type banking_error :: {:error,
    :wrong_arguments                |
    :user_already_exists            |
    :user_does_not_exist            |
    :not_enough_money               |
    :sender_does_not_exist          |
    :receiver_does_not_exist        |
    :too_many_requests_to_user      |
    :too_many_requests_to_sender    |
    :too_many_requests_to_receiver  |
    :too_much_money
  }

  @spec create_user(user :: String.t) :: :ok | banking_error
  def create_user(user) do
    case assert_user(user) do
      :ok ->
        {:error, :user_already_exists}
      _ ->
        GenServer.call(__MODULE__, {:create_user, user})
    end
  end

  @spec deposit(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
    with :ok <- assert_user(user),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, new_balance} <- GenServer.call(__MODULE__, {:deposit, user, amount2, currency})
    do
      amount_to_float(new_balance)
    end
  end

  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
    with :ok <- assert_user(user),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, new_balance} <- GenServer.call(__MODULE__, {:withdraw, user, amount2, currency})
    do
      amount_to_float(new_balance)
    end
  end

  @spec get_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | banking_error
  def get_balance(user, currency) do
    with :ok <- assert_user(user)
    do
      amount = do_get_balance(user, currency)
      amount_to_float(amount)
    end
  end

  @spec send(from_user :: String.t, to_user :: String.t, amount :: number, currency :: String.t) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
    with :ok <- assert_user(from_user, :sender_does_not_exist),
      :ok <- assert_user(to_user, :receiver_does_not_exist),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, from_user_balance, to_user_balance} <- GenServer.call(__MODULE__, {:send, from_user, to_user, amount2, currency}),
      {:ok, from_user_balance2} <- amount_to_float(from_user_balance),
      {:ok, to_user_balance2} <- amount_to_float(to_user_balance)
    do
      {:ok, from_user_balance2, to_user_balance2}
    end
  end

  def assert_user(user) do
    assert_user(user, :user_does_not_exist)
  end

  def assert_user(user, error) do
    case :ets.lookup(__MODULE__, user) do
      [] -> {:error, error}
      _ -> :ok
    end
  end

  def float_to_amount(number) when is_number(number) do
    case number < 0 do
      true ->
        {:error, :wrong_arguments}
      false ->
        scaled = number * 100
        rounded = round(scaled)
        case abs(scaled - rounded) > 1.0e-6 do
          true ->
            {:error, :wrong_arguments}
          false ->
            {:ok, rounded}
        end
    end
  end

  def float_to_amount(_) do
    {:error, :wrong_arguments}
  end
  
  def amount_to_float(amount) do
    scaled = amount / 100
    rounded = Float.round(scaled, 2)
    {:ok, rounded}
  end

  def do_get_balance(user, currency) do
    case :ets.lookup(__MODULE__, {user, currency}) do
      [] ->
        0
      [{ {_user, _currency}, amount }] ->
        amount
    end
  end

  def do_set_balance(user, currency, amount) do
    :ets.insert(__MODULE__, { {user, currency}, amount })
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:set, :protected, :named_table])
    {:ok, :none}
  end

  @impl true
  def handle_call({:create_user, user}, _from, state) do
    result = case assert_user(user) do
      :ok ->
        {:error, :user_already_exists}
      _ ->
        :ets.insert(__MODULE__, {user, :ok})
        :ok
    end
    {:reply, result, state}
  end

  def handle_call({:deposit, user, amount, currency}, _from, state) do
    current = do_get_balance(user, currency)
    new = current + amount
    result = case new > 1_000_000_000_000 do
      true ->
        {:error, :too_much_money}
      false ->
        do_set_balance(user, currency, new)
        {:ok, new}
    end
    {:reply, result, state}
  end

  def handle_call({:withdraw, user, amount, currency}, _from, state) do
    current = do_get_balance(user, currency)
    result = case current < amount do
      true ->
        {:error, :not_enough_money}
      false ->
        new = current - amount
        do_set_balance(user, currency, new)
        {:ok, new}
    end
    {:reply, result, state}
  end

  def handle_call({:send, user_from, user_to, amount, currency}, _from, state) do
    current_from = do_get_balance(user_from, currency)
    current_to = do_get_balance(user_to, currency)
    result = case current_from < amount do
      true ->
        {:error, :not_enough_money}
      false ->
        new_from = current_from - amount
        new_to = current_to + amount
        case new_to > 1_000_000_000_000 do
          true ->
            {:error, :too_much_money}
          false ->
            do_set_balance(user_from, currency, new_from)
            do_set_balance(user_to, currency, new_to)
            {:ok, new_from, new_to}
        end
    end
    {:reply, result, state}
  end
end
