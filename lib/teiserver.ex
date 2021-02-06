defmodule Teiserver do
  # Call Teiserver.test() to test a few things quickly
  def test do
    IO.puts "Client list"
    ConCache.get(:lists, :clients)
    
    IO.puts "Client entry Teifion"
    ConCache.get(:clients, "Teifion")
    
    IO.puts "User list"
    ConCache.get(:lists, :users)
    
    IO.puts "User entry Teifion"
    ConCache.get(:users, "Teifion")
  end
  
  def clientstatus(name, new_status) do
    Phoenix.PubSub.broadcast Teiserver.PubSub, "client_updates", {:new_status, name, new_status}
  end
  # Teiserer.clientstatus("Addas", "12")
end
