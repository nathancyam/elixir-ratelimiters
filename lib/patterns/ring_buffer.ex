defmodule Patterns.RingBuffer do
  use GenServer

  # The approach uses a ring buffer. If you're not familiar with them,
  #  they are a fix-sized array or linked list that you iterate through monotonically,
  # wrapping around to the beginning when you are at the limit.
  #   Our ring buffer will hold timestamps and should be initialized to hold 0's
  #     -- ensuring that only someone with a time machine could be rate limited before
  #     they send any requests. The size of the buffer is the rate limit's value, expressed
  #       in whatever time unit you find convenient.
  #

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    buffer_length = Keyword.fetch!(opts, :buffer_length)
    rate_limit_interval = Keyword.fetch!(opts, :rate_limit_interval)

    ring =
      for _ <- 1..buffer_length, do: 0

    state = %{
      buffer_length: buffer_length,
      current_index: 0,
      ring: ring,
      rate_limit_interval: rate_limit_interval
    }

    {:ok, state}
  end

  def make_request(pid, worker_fun) do
    GenServer.call(pid, {:enqueue, worker_fun})
  end

  # As each request comes in, you fetch the value from the buffer at the current position
  # and compare it to current time. If the value from the buffer is more than the current
  # time minus the rate limit interval you're using, then you return a 420 to the client and
  # are done. If not, their request is ok and you should serve it normally, but first you store
  # the current time stamp in the buffer and then advance the counter/index.
  @impl true
  def handle_call({:enqueue, worker_fun}, _from, state) do
    %{
      ring: ring,
      current_index: current_index,
      rate_limit_interval: rate_limit_interval,
      buffer_length: buffer_length
    } = state

    now = :os.system_time(:second)
    buffer_value = Enum.at(ring, current_index)

    if now - rate_limit_interval < buffer_value do
      {:reply, {:error, :rate_limited}, state}
    else
      new_state =
        state
        |> Map.update!(:ring, fn old_ring ->
          List.update_at(old_ring, current_index, fn _ -> now end)
        end)
        |> Map.update!(:current_index, fn old_index ->
          new_index = old_index + 1

          if new_index > buffer_length - 1 do
            0
          else
            new_index
          end
        end)

      {:reply, worker_fun.(), new_state}
    end
  end
end
