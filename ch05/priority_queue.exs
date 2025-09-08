"""
  Coded and tested on:
      Elixir 1.18.4
      Erlang/OTP 27
"""

defmodule PriorityQueue do
  def new do
    :gb_trees.empty()
  end
  def put(pqueue, priority, value) do
    :gb_trees.insert({priority, DateTime.now("Etc/UTC")}, value, pqueue)
  end
  def get(pqueue) do
    # get smallest element in the tree
    if :gb_trees.is_empty(pqueue) do
      {nil, pqueue}
    else
      {_, value, npqueue} = :gb_trees.take_smallest(pqueue)
      {value, npqueue}
    end
  end
end
