"""
  Coded and tested on:
      Elixir 1.18.4
      Erlang/OTP 27
"""

defmodule Mailbox do
  def loop do
    receive do
      {:important, fun, args} -> IO.puts(fun.(args))
    after
      0 ->
        receive do
          {:important, fun, args} -> IO.puts(fun.(args))
          {:normal, fun, args} -> IO.puts(fun.(args))
        end
    end
    loop()
  end
  def start do
    pid = spawn(__MODULE__, :loop, [])
    Process.register(pid, :mailbox)
    pid
  end
  def publish_important(fun, args) do
    send(:mailbox, {:important, fun, args})
  end
  def publish_normal(fun, args) do
    send(:mailbox, {:normal, fun, args})
  end
end

"""
    test

    observe if it prints:
    normal1
    important
    normal2
"""

pid = Mailbox.start
wait_and_put = fn {str} -> Process.sleep(2000); str end
put = fn {str} -> str end

Mailbox.publish_normal(wait_and_put, {"normal1"})
Mailbox.publish_normal(put, {"normal2"})
Mailbox.publish_important(put, {"important"})
