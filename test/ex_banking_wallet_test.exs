defmodule ExBankingWalletTest do
  use ExUnit.Case
  doctest ExBanking.Wallet

  test "withdraw precheck" do
    {:ok, pid} = ExBanking.Wallet.start_link(:null)
    {:ok, txid} = ExBanking.Wallet.deposit(pid, 100, "bar")
    {:ok, 100} = ExBanking.Wallet.commit(pid, txid)

    assert {:ok, txid2} = ExBanking.Wallet.withdraw(pid, 100, "bar")
    assert {:error, :not_enough_money} == ExBanking.Wallet.withdraw(pid, 1, "bar")
  end

  test "deposit precheck" do
    a_lot = 1_000_000_000_000 - 1
    {:ok, pid} = ExBanking.Wallet.start_link(:null)
    {:ok, txid} = ExBanking.Wallet.deposit(pid, a_lot, "bar")
    {:ok, ^a_lot} = ExBanking.Wallet.commit(pid, txid)

    assert {:error, :too_much_money} = ExBanking.Wallet.deposit(pid, 1, "bar")
  end

  test "rollback" do
    {:ok, pid} = ExBanking.Wallet.start_link(:null)
    {:ok, txid} = ExBanking.Wallet.deposit(pid, 100, "bar")
    {:ok, 100} = ExBanking.Wallet.commit(pid, txid)
    {:ok, txid2} = ExBanking.Wallet.withdraw(pid, 100, "bar")

    assert {:ok, 100} == ExBanking.Wallet.rollback(pid, txid2)
    assert {:error, :no_tx} == ExBanking.Wallet.rollback(pid, txid2)

    assert {:ok, txid3} = ExBanking.Wallet.withdraw(pid, 100, "bar")
    assert {:ok, 0} == ExBanking.Wallet.commit(pid, txid3)

  end
end
