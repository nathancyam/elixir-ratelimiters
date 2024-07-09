defmodule Patterns.RingBufferTest do
  use ExUnit.Case

  alias Patterns.RingBuffer

  setup do
    pid =
      start_supervised!(
        {RingBuffer,
         [
           buffer_length: 50,
           rate_limit_interval: 1
         ]}
      )

    %{pid: pid}
  end

  test "go around the buffer and try", %{pid: pid} do
    tasks =
      for i <- 0..10 do
        Task.async(fn ->
          out =
            RingBuffer.make_request(pid, fn ->
              "doing first work with index: #{i}"
            end)

          IO.inspect(out, label: "First")

          second =
            RingBuffer.make_request(pid, fn ->
              "doing second work with index: #{i}"
            end)

          IO.inspect(second, label: "Second")
        end)
      end

    Task.await_many(tasks)
  end
end
