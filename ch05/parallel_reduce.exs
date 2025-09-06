"""
  Coded and tested on:
      Elixir 1.18.4
      Erlang/OTP 27

  function `map` is given by the book.
  function `reduce` is written by me.

  Testing included.

"""

defmodule Parallel do
  def map(collection, fun) do
    parent = self()

    processes = Enum.map(collection, fn(e) ->
      spawn_link(fn() ->
        send(parent, {self(), fun.(e)})
      end)
    end)

    Enum.map(processes, fn(pid) ->
      receive do
        {^pid, result} -> result
      end
    end)
  end

  def reduce(collection, acc, fun) do
    # `acc` must be an identity of `fun`
    parent = self()

    full = length(collection)
    half = div(full, 2)

    left = Enum.slice(collection, 0, half)
    right = Enum.slice(collection, half..full)

    processes = Enum.map([left, right], fn(prt) ->
      spawn_link(fn() ->
        send(parent, {self(), Enum.reduce(prt, acc, fun)})
      end)
    end)

    results = Enum.map(processes, fn(pid) ->
      receive do
        {^pid, result} -> result
      end
    end)

    Enum.reduce(results, acc, fun)
  end
end

########
#      #
# Test #
#      #
########

numbers = [Enum.to_list(1..100), Enum.to_list(1..1000), Enum.to_list(1..10000), Enum.to_list(1..100000)]
comments = ["hundred", "thousand", "ten thousand", "hundred thousand"]
tests = Enum.zip(numbers, comments)

reducer = [fn (elm, acc) -> elm + acc end,
           fn (elm, acc) -> elm * acc end]
identity = [0, 1]
roles = ["adding", "multiplying"]

functions = Enum.zip(reducer, identity)
inner_tests = Enum.zip(roles, functions)

Enum.each(tests, fn(info) ->
  number = elem(info, 0)
  comment = elem(info, 1)

  IO.puts("--------------------")
  IO.puts("Test with #{comment}")
  IO.puts("--------------------")

  Enum.each(inner_tests, fn(funcs) ->
    role = elem(funcs, 0)
    reducer = elem(elem(funcs, 1), 0)
    init = elem(elem(funcs, 1), 1)

    IO.puts("    with #{role} function:")

    default = :timer.tc(fn() -> Enum.reduce(number, init, reducer) end)
    parallel = :timer.tc(fn() -> Parallel.reduce(number, init, reducer) end)

    IO.puts("        Enum.reduce(): #{elem(default, 0)} μs\n        Parallel.reduce(): #{elem(parallel, 0)} μs")
    IO.puts("        Does the result same?: #{elem(default, 1) == elem(parallel, 1)}")
  end)
end)
