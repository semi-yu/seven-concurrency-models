"""
  Coded and tested on:
      Elixir 1.18.4
      Erlang/OTP 27
"""

defmodule CacheActor do
  def loop(pages, size) do
    receive do
      {:put, url, page} ->
        new_pages = Map.put(pages, url, page)
        new_size = size + byte_size(page)
        loop(new_pages, new_size)

      {:get, sender, ref, url} ->
        send(sender, {:ok, ref, pages[url]})
        loop(pages, size)

      {:size, sender, ref} ->
        send(sender, {:ok, ref, size})
        loop(pages, size)

      {:terminate} -> # Terminate request -- don't recurse
    end
  end

  def start_link do
    spawn_link(__MODULE__, :loop, [Map.new, 0])
  end

  def put(url, page) do
    send(self(), {:put, url, page})
  end

  def get(url) do
    ref = make_ref()
    send(self(), {:get, self(), ref, url})
    receive do
      {:ok, ^ref, page} -> page
      after 1000 -> nil
    end
  end

  def size do
    ref = make_ref()
    send(self(), {:size, self(), ref})

    receive do
      {:ok, ^ref, s} -> s
      after 1000 -> nil
    end
  end

  def terminate do
    send(self(), {:terminate})
  end
end

defmodule CacheSupervisor do
  def start(nact) do
    pid = spawn(__MODULE__, :sysloop, [nact])
    Process.register(pid, __MODULE__)
    pid
  end

  def sysloop(nact) do
    Process.flag(:trap_exit, true)

    pids = for _ <- 1..nact do
      CacheActor.start_link
    end

    loop(pids, nact)
  end

  def loop(pids, nact) do
    IO.inspect(pids)

    receive do
      {:put, url, page} ->
        pid = Enum.at(pids, route(url, nact))
        send(pid, {:put, url, page})
        loop(pids, nact)

      {:get, from, ref, url} ->
        pid = Enum.at(pids, route(url, nact))
        send(pid, {:get, from, ref, url})
        loop(pids, nact)

      {:EXIT, pid, :normal} ->
        IO.puts("cache #{pid} terminated normally")

      {:EXIT, pid, reason} ->
        IO.puts("cache #{inspect pid} terminated abnormally")
        IO.puts("    reason: #{inspect reason}")
        IO.puts("    response: restarting the terminated cache")
        loop(repair(pids, pid), nact)
    after
      1000 -> nil
    end
  end

  def route(url, nact) do
    Integer.mod(hash(url), nact)
  end

  def hash(url) do
    h = 134

    url
    |> String.to_charlist()
    |> Enum.reduce(0, fn elm, acc -> acc + elm * h end)
  end

  def put(url, page) do
    send(__MODULE__, {:put, url, page})
  end

  def get(url) do
    ref = make_ref()
    send(__MODULE__, {:get, self(), ref, url})

    receive do
      {:ok, ^ref, page} -> {:ok, page}
    after
      1000 -> {:error, :nil}
    end
  end

  def repair(pids, terminated) do
    [CacheActor.start_link | Enum.filter(pids, fn p -> p != terminated end)]
  end
end

"""
    test

    (1) put five pages
    (2) get five pages
    (3) put one page, failing
    (4) cache repair: observe the difference of pid list
    (5) put one page
    (6) get one page
    (7) get one page never put

"""

CacheSupervisor.start(3)
IO.puts("starting cache...")

CacheSupervisor.put("google.com", "welcome to the google!")
CacheSupervisor.put("naver.com", "네이버에 오신 것을 환영합니다.")
CacheSupervisor.put("navet.com", "You mean naver.com? Redirecting you to naver.com")
CacheSupervisor.put("yahoo.com", "Yahoo | Mail, Weather, Search, politics, News, Finance, Sports & Videos")
CacheSupervisor.put("yahoo.co.kr", "Yahoo.co.kr had shut down service. Redirecting you to yahoo.com")

IO.inspect(CacheSupervisor.get("google.com"))
IO.inspect("google.com -> cache ##{CacheSupervisor.route("google.com", 3)}")

IO.inspect(CacheSupervisor.get("naver.com"))
IO.inspect("naver.com -> cache ##{CacheSupervisor.route("naver.com", 3)}")

IO.inspect(CacheSupervisor.get("navet.com"))
IO.inspect("navet.com -> cache ##{CacheSupervisor.route("navet.com", 3)}")

IO.inspect(CacheSupervisor.get("yahoo.com"))
IO.inspect("yahoo.com -> cache ##{CacheSupervisor.route("yahoo.com", 3)}")

IO.inspect(CacheSupervisor.get("yahoo.co.kr"))
IO.inspect("yahoo.co.kr -> cache ##{CacheSupervisor.route("yahoo.com", 3)}")

CacheSupervisor.put("paulbutcher.com", nil)
IO.inspect("paulbutcher.com -> cache ##{CacheSupervisor.route("paulbutcher.com", 3)}")

CacheSupervisor.put("paulbutcher.com", "I gave you another tasks to solve.")
IO.inspect(CacheSupervisor.get("paulbutcher.com"))
IO.inspect(CacheSupervisor.get("haventput.com"))

IO.puts("terminating cache...")
