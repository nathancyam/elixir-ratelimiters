defmodule PatternsTest do
  use ExUnit.Case
  doctest Patterns

  test "greets the world" do
    assert Patterns.hello() == :world
  end
end
