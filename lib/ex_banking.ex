defmodule ExBanking do
  @moduledoc """
  Documentation for ExBanking.
  """

  @scale 100
  @epsilon 1.0e-6
  @messages_throttle 10

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
    ExBanking.Wallets.create_user(user)
  end

  @spec deposit(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
    with {:ok, user_id} <- lookup_user(user),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, txid} <- ExBanking.Wallet.deposit(user_id, amount2, currency),
      {:ok, new_balance} <- ExBanking.Wallet.commit(user_id, txid)
    do
      amount_to_float(new_balance)
    end
  end

  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
    with {:ok, user_id} <- lookup_user(user),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, txid} <- ExBanking.Wallet.withdraw(user_id, amount2, currency),
      {:ok, new_balance} <- ExBanking.Wallet.commit(user_id, txid)
    do
      amount_to_float(new_balance)
    end
  end

  @spec get_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | banking_error
  def get_balance(user, currency) do
    with {:ok, user_id} <- lookup_user(user)
    do
      amount = ExBanking.Wallet.get_balance(user_id, currency)
      amount_to_float(amount)
    end
  end

  @spec send(from_user :: String.t, to_user :: String.t, amount :: number, currency :: String.t) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
    with {:ok, from_user_id} <- lookup_user(from_user, :sender_does_not_exist, :too_many_requests_to_sender),
      {:ok, to_user_id} <- lookup_user(to_user, :receiver_does_not_exist, :too_many_requests_to_receiver),
      {:ok, amount2} <- float_to_amount(amount),
      {:ok, from_user_balance, to_user_balance} <- do_send(from_user_id, to_user_id, amount2, currency),
      {:ok, from_user_balance2} <- amount_to_float(from_user_balance),
      {:ok, to_user_balance2} <- amount_to_float(to_user_balance)
    do
      {:ok, from_user_balance2, to_user_balance2}
    end
  end

  def do_send(from_user_id, to_user_id, amount, currency) do
    case ExBanking.Wallet.withdraw(from_user_id, amount, currency) do
      {:ok, txid_from} ->
        case ExBanking.Wallet.deposit(to_user_id, amount, currency) do
          {:ok, txid_to} ->
            {:ok, from_user_balance} = ExBanking.Wallet.commit(from_user_id, txid_from)
            {:ok, to_user_balance} = ExBanking.Wallet.commit(to_user_id, txid_to)
            {:ok, from_user_balance, to_user_balance}
          error ->
            {:ok, _} = ExBanking.Wallet.rollback(from_user_id, txid_from)
            error
        end
      error ->
        error
    end
  end

  def lookup_user(user) do
    lookup_user(user, :user_does_not_exist, :too_many_requests_to_user)
  end

  def lookup_user(user, error, throttle_error) do
    case ExBanking.Wallets.lookup(user) do
      {:error, :user_does_not_exist} ->
        {:error, error}
      {:ok, pid} ->
        {:message_queue_len, messages} = :erlang.process_info(pid, :message_queue_len)
        case messages >= @messages_throttle do
          true ->
            {:error, throttle_error}
          false ->
            {:ok, pid}
        end
    end
  end

  def float_to_amount(number) when is_number(number) do
    case number < 0 do
      true ->
        {:error, :wrong_arguments}
      false ->
        scaled = number * @scale
        rounded = round(scaled)
        case abs(scaled - rounded) > @epsilon do
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
    scaled = amount / @scale
    rounded = Float.round(scaled, 2)
    {:ok, rounded}
  end
end
