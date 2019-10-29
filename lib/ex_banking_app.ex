defmodule ExBankingApp do
  use Application

  @impl true
  def start(_type, _args) do
    children = [%{id: ExBanking, start: {ExBanking, :start_link, []}}]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
