defmodule Discord.SortedSet.New.Test do
  use ExUnit.Case

  alias Discord.SortedSet

  describe "new/1" do
    test "returns a new reference, when called without any arguments" do
      assert set = SortedSet.new()
      assert is_reference(set)
    end
  end
end
