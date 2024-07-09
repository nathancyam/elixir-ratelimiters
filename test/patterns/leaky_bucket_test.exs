defmodule Patterns.LeakyBucketTest do
  use ExUnit.Case

  alias Patterns.LeakyBucket

  setup do
    pid =
      start_supervised!(%{
        id: LeakyBucket,
        start: {LeakyBucket, :start_link, [:test, [requests_per_second: 1]]}
      })

    %{pid: pid}
  end

  test "message" do
    tasks =
      for n <- 1..20 do
        Task.async(fn ->
          IO.inspect("waiting with #{n}")
          LeakyBucket.wait_for_turn(:test)
          IO.inspect("done with #{n}")
        end)
      end

    Task.await_many(tasks, :infinity)
  end
end
