defmodule Patterns.LeakyBucket do
  use GenServer

  defmodule State do
    @enforce_keys [:requests_per_second, :requests_pop_in_ms]

    defstruct [
      :requests_per_second,
      :requests_pop_in_ms,
      requests_queue: :queue.new(),
      queue_length: 0
    ]

    def new(requests_per_second) when is_integer(requests_per_second) do
      requests_pop_in_ms =
        floor(:timer.seconds(1) / requests_per_second)

      %__MODULE__{
        requests_per_second: requests_per_second,
        requests_pop_in_ms: requests_pop_in_ms
      }
    end

    def wait_for_turn(%__MODULE__{queue_length: prev_queue_length} = state, from_ref) do
      new_state =
        state
        |> Map.update!(:requests_queue, &:queue.in(from_ref, &1))
        |> Map.update!(:queue_length, &(&1 + 1))

      if prev_queue_length == 0 do
        {:schedule_next_run, state.requests_pop_in_ms, new_state}
      else
        {:ok, new_state}
      end
    end

    def pop(%__MODULE__{} = state, runner \\ &GenServer.reply(&1, :ok))
        when is_function(runner, 1) do
      {{:value, from_ref}, queue} = :queue.out(state.requests_queue)

      :ok = runner.(from_ref)

      new_state =
        state
        |> Map.put(:requests_queue, queue)
        |> Map.update!(:queue_length, &(&1 - 1))

      {:schedule_next_run, new_state.requests_pop_in_ms, new_state}
    end
  end

  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: via_registry(name))
  end

  @impl GenServer
  def init(opts) do
    requests_per_second = Keyword.fetch!(opts, :requests_per_second)

    {:ok, State.new(requests_per_second)}
  end

  def wait_for_turn(name) do
    GenServer.call(via_registry(name), :wait_for_turn, :infinity)
  end

  @impl GenServer
  def handle_call(:wait_for_turn, from, state) do
    case State.wait_for_turn(state, from) do
      {:ok, state} ->
        {:noreply, state}

      {:schedule_next_run, next_run_ms, state} ->
        {:noreply, state, {:continue, {:schedule_next_run, next_run_ms}}}
    end
  end

  @impl GenServer
  def handle_continue({:schedule_next_run, next_run_ms}, state) do
    Process.send_after(self(), :pop_request, next_run_ms)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:pop_request, state) do
    {:schedule_next_run, next_run_ms, state} = State.pop(state)
    {:noreply, state, {:continue, {:schedule_next_run, next_run_ms}}}
  end

  defp via_registry(name) do
    {:via, Registry, {Patterns.Registry, name}}
  end
end
