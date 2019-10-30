defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking
  
#  setup do
#    :ok = Application.stop(:ex_banking)
#    :ok = Application.start(:ex_banking)
#  end

  test "user create" do
    assert ExBanking.create_user("foo") == :ok
    assert ExBanking.create_user("foo") == {:error, :user_already_exists}
    assert ExBanking.get_balance("foo", "bar") == {:ok, 0.0}
  end

  test "no user" do
    assert ExBanking.deposit("noone", 100, "bar") == {:error, :user_does_not_exist}
    assert ExBanking.withdraw("noone", 100, "bar") == {:error, :user_does_not_exist}
    assert ExBanking.get_balance("noone", "bar") == {:error, :user_does_not_exist}
  end

  test "send no user" do
    ExBanking.create_user("foo3")
    ExBanking.deposit("foo3", 1, "bar")
    assert ExBanking.send("foo3", "noone", 1, "bar") == {:error, :receiver_does_not_exist}
    assert ExBanking.send("noone", "foo3", 1, "bar") == {:error, :sender_does_not_exist}
  end

  test "deposit-withdraw-balance" do
    ExBanking.create_user("foo2")
    assert ExBanking.deposit("foo2", 100, "bar") == {:ok, 100.0}
    assert ExBanking.withdraw("foo2", 90, "bar") == {:ok, 10.0}
    assert ExBanking.deposit("foo2", 100, "bar") == {:ok, 110.0}
    assert ExBanking.get_balance("foo2", "bar") == {:ok, 110.0}
  end

  test "send" do
    ExBanking.create_user("foo4a")
    ExBanking.create_user("foo4b")
    ExBanking.deposit("foo4a", 100, "bar")
    assert ExBanking.send("foo4a", "foo4b", 10, "bar") == {:ok, 90.0, 10.0}
  end

  test "not_enough_money" do
    ExBanking.create_user("foo5")
    ExBanking.create_user("foo5b")
    ExBanking.deposit("foo5", 100, "bar")
    assert ExBanking.withdraw("foo5", 999, "bar") == {:error, :not_enough_money}
    assert ExBanking.send("foo5", "foo5b", 1000, "bar") == {:error, :not_enough_money}
    assert ExBanking.get_balance("foo5", "bar") == {:ok, 100.0}
  end

  test "too_much_money" do
    ExBanking.create_user("foo6")
    ExBanking.create_user("foo6b")
    ExBanking.deposit("foo6", 5_000_000_000, "bar")
    ExBanking.deposit("foo6b", 5_000_000_001, "bar")
    assert ExBanking.deposit("foo6", 5_000_000_001, "bar") == {:error, :too_much_money}
    assert ExBanking.send("foo6b", "foo6", 5_000_000_001, "bar") == {:error, :too_much_money}
    assert ExBanking.get_balance("foo6", "bar") == {:ok, 5.0e9}
  end

  test "wrong_arguments" do
    ExBanking.create_user("foo7")
    assert ExBanking.deposit("foo7", 1.005, "bar") == {:error, :wrong_arguments}
    assert ExBanking.deposit("foo7", -1, "bar") == {:error, :wrong_arguments}
    assert ExBanking.deposit("foo7", "nan", "bar") == {:error, :wrong_arguments}
  end

end
