require "minitest_helper"

module TestWinRM

  class Transport < Minitest::Test

    def test_that_it_has_a_version_number
      refute_nil ::WinRM::Transport::VERSION
    end

    def test_it_does_something_useful
      assert false
    end
  end
end
