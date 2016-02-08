# -*- encoding: utf-8 -*-
#
# Author:: Fletcher (<fnichol@nichol.ca>)
#
# Copyright (C) 2015, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative "../../spec_helper"

require "winrm/transport/command_executor"
require "winrm/exceptions/exceptions"

require "base64"
require "securerandom"
require "winrm"

describe WinRM::Transport::CommandExecutor do

  let(:logged_output)   { StringIO.new }
  let(:logger)          { Logger.new(logged_output) }
  let(:shell_id)        { "shell-123" }
  let(:executor_args)   { [service, logger] }

  let(:executor) do
    WinRM::Transport::CommandExecutor.new(*executor_args)
  end

  let(:service) do
    s = mock("winrm_service")
    s.responds_like_instance_of(::WinRM::WinRMWebService)
    s
  end

  let(:closer) do
    c = mock("shell_closer")
    c.stubs(:for)
    c
  end

  let(:version_output) do
    o = ::WinRM::Output.new
    o[:exitcode] = 0
    o[:data].concat([{ :stdout => "6.3.9600.0\r\n" }])
    o
  end

  before do
    service.stubs(:open_shell).returns(shell_id)

    stub_powershell_script(shell_id,
      "[environment]::OSVersion.Version.tostring()", version_output)
  end

  describe "#close" do

    it "calls service#close_shell" do
      executor.open
      service.expects(:close_shell).with(shell_id)

      executor.close
    end

    it "only calls service#close_shell once for multiple calls" do
      executor.open
      service.expects(:close_shell).with(shell_id).once

      executor.close
      executor.close
      executor.close
    end

    it "undefines a finalizer on the object if a closer is set" do
      service.stubs(:close_shell)
      executor_args << closer
      ObjectSpace.stubs(:define_finalizer).with { |e, _| e == executor }
      ObjectSpace.expects(:undefine_finalizer).with(executor)
      executor.open

      executor.close
    end
  end

  describe "#open" do

    it "calls service#open_shell" do
      service.expects(:open_shell).returns(shell_id)

      executor.open
    end

    it "defines a finalizer on the object if a closer is set" do
      executor_args << closer
      new_closer = "new_closer"
      closer.expects(:for).with(shell_id).returns(new_closer)
      ObjectSpace.expects(:define_finalizer).with do |e, c|
        e.must_equal(executor)
        c.must_equal(new_closer)
      end

      executor.open
    end

    it "returns a shell id as a string" do
      executor.open.must_equal shell_id
    end

    describe "when a registry key marked for deletion fault occurs" do

      let(:fault) do
        msg = "Illegal operation attempted on a registry key that has been marked for deletion"
        code = 2147943418 # the fault code returned by windows when this error occurs
        ::WinRM::WinRMWSManFault.new(msg, code)
      end

      let(:max_tries) { ::WinRM::Transport::CommandExecutor::MAX_RETRIES + 1 }

      before do
        service.unstub(:open_shell)
      end

      it "retries up to 4 times before giving up" do
        service.expects(:open_shell).raises(fault).times(max_tries)
        assert_raises(::WinRM::WinRMWSManFault) { executor.open }
      end

      it "succeeds if the fault occurs less than the maximum allowed times" do
        service.expects(:open_shell).raises(fault).times(2).then.returns(shell_id)
        executor.open
        executor.shell.must_equal shell_id
      end
    end

    describe "for modern windows distributions" do

      let(:version_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "6.3.9600.0\r\n" }])
        o
      end

      it "sets #max_commands to 1500 - 2" do
        executor.max_commands.must_equal nil
        executor.open

        executor.max_commands.must_equal(1500 - 2)
      end
    end

    describe "for older/legacy windows distributions" do

      let(:version_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "6.1.8500.0\r\n" }])
        o
      end

      it "sets #max_commands to 15 - 2" do
        executor.max_commands.must_equal nil
        executor.open

        executor.max_commands.must_equal(15 - 2)
      end
    end
  end

  describe "#run_cmd" do

    describe "when #open has not been previously called" do

      it "raises a WinRMError error" do
        err = proc { executor.run_cmd("nope") }.must_raise ::WinRM::WinRMError
        err.message.must_equal "#{executor.class}#open must be called " \
          "before any run methods are invoked"
      end
    end

    describe "when #open has been previously called" do

      let(:command_id) { "command-123" }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([
          { :stdout => "Hello\r\n" },
          { :stderr => "Psst\r\n" }
        ])
        o
      end

      before do
        stub_cmd(shell_id, "echo", ["Hello"], echo_output, command_id)

        executor.open
      end

      it "calls service#run_command" do
        service.expects(:run_command).with(shell_id, "echo", ["Hello"])

        executor.run_cmd("echo", ["Hello"])
      end

      it "calls service#get_command_output to get results" do
        service.expects(:get_command_output).with(shell_id, command_id)

        executor.run_cmd("echo", ["Hello"])
      end

      it "calls service#get_command_output with a block to get results" do
        blk = proc { |_, _| "something" }
        service.expects(:get_command_output).with(shell_id, command_id, &blk)

        executor.run_cmd("echo", ["Hello"], &blk)
      end

      it "returns an Output object hash" do
        executor.run_cmd("echo", ["Hello"]).must_equal echo_output
      end

      it "runs the block  in #get_command_output when given" do
        io_out = StringIO.new
        io_err = StringIO.new

        output = executor.run_cmd("echo", ["Hello"]) do |stdout, stderr|
          io_out << stdout if stdout
          io_err << stderr if stderr
        end

        io_out.string.must_equal "Hello\r\n"
        io_err.string.must_equal "Psst\r\n"
        output.must_equal echo_output
      end
    end

    describe "when called many times over time" do

      # use a "old" version of windows with lower max_commands threshold
      # to trigger quicker shell recyles
      let(:version_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "6.1.8500.0\r\n" }])
        o
      end

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "Hello\r\n" }])
        o
      end

      before do
        service.stubs(:open_shell).returns("s1", "s2")
        service.stubs(:close_shell)
        service.stubs(:run_command).yields("command-xxx")
        service.stubs(:get_command_output).returns(echo_output)
        stub_powershell_script("s1",
          "[environment]::OSVersion.Version.tostring()", version_output)
      end

      it "resets the shell when #max_commands threshold is tripped" do
        iterations = 35
        reset_times = iterations / (15 - 2)

        service.expects(:close_shell).times(reset_times)
        executor.open
        iterations.times { executor.run_cmd("echo", ["Hello"]) }

        logged_output.string.lines.select { |l|
          l =~ debug_line_with("[CommandExecutor] Resetting WinRM shell")
        }.size.must_equal reset_times
      end
    end
  end

  describe "#run_powershell_script" do

    describe "when #open has not been previously called" do

      it "raises a WinRMError error" do
        err = proc {
          executor.run_powershell_script("nope")
        }.must_raise ::WinRM::WinRMError
        err.message.must_equal "#{executor.class}#open must be called " \
          "before any run methods are invoked"
      end
    end

    describe "when #open has been previously called" do

      let(:command_id) { "command-123" }

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([
          { :stdout => "Hello\r\n" },
          { :stderr => "Psst\r\n" }
        ])
        o
      end

      before do
        stub_powershell_script(shell_id, "echo Hello", echo_output, command_id)

        executor.open
      end

      it "calls service#run_command" do
        service.expects(:run_command).with(
          shell_id,
          "powershell",
          ["-encodedCommand", ::WinRM::PowershellScript.new("echo Hello").encoded]
        )

        executor.run_powershell_script("echo Hello")
      end

      it "calls service#get_command_output to get results" do
        service.expects(:get_command_output).with(shell_id, command_id)

        executor.run_powershell_script("echo Hello")
      end

      it "calls service#get_command_output with a block to get results" do
        blk = proc { |_, _| "something" }
        service.expects(:get_command_output).with(shell_id, command_id, &blk)

        executor.run_powershell_script("echo Hello", &blk)
      end

      it "returns an Output object hash" do
        executor.run_powershell_script("echo Hello").must_equal echo_output
      end

      it "runs the block  in #get_command_output when given" do
        io_out = StringIO.new
        io_err = StringIO.new

        output = executor.run_powershell_script("echo Hello") do |stdout, stderr|
          io_out << stdout if stdout
          io_err << stderr if stderr
        end

        io_out.string.must_equal "Hello\r\n"
        io_err.string.must_equal "Psst\r\n"
        output.must_equal echo_output
      end
    end

    describe "when called many times over time" do

      # use a "old" version of windows with lower max_commands threshold
      # to trigger quicker shell recyles
      let(:version_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "6.1.8500.0\r\n" }])
        o
      end

      let(:echo_output) do
        o = ::WinRM::Output.new
        o[:exitcode] = 0
        o[:data].concat([{ :stdout => "Hello\r\n" }])
        o
      end

      before do
        service.stubs(:open_shell).returns("s1", "s2")
        service.stubs(:close_shell)
        service.stubs(:run_command).yields("command-xxx")
        service.stubs(:get_command_output).returns(echo_output)
        stub_powershell_script("s1",
          "[environment]::OSVersion.Version.tostring()", version_output)
      end

      it "resets the shell when #max_commands threshold is tripped" do
        iterations = 35
        reset_times = iterations / (15 - 2)

        service.expects(:close_shell).times(reset_times)
        executor.open
        iterations.times { executor.run_powershell_script("echo Hello") }

        logged_output.string.lines.select { |l|
          l =~ debug_line_with("[CommandExecutor] Resetting WinRM shell")
        }.size.must_equal reset_times
      end
    end
  end

  describe "#shell" do

    it "is initially nil" do
      executor.shell.must_equal nil
    end

    it "is set after #open is called" do
      executor.open

      executor.shell.must_equal shell_id
    end
  end

  def decode(powershell)
    Base64.strict_decode64(powershell).encode("UTF-8", "UTF-16LE")
  end

  def debug_line_with(msg)
    %r{^D, .* : #{Regexp.escape(msg)}}
  end

  def regexify(string)
    Regexp.new(Regexp.escape(string))
  end

  def regexify_line(string)
    Regexp.new("^#{Regexp.escape(string)}$")
  end

  # rubocop:disable Metrics/ParameterLists
  def stub_cmd(shell_id, cmd, args, output, command_id = nil, &block)
    command_id ||= SecureRandom.uuid

    service.stubs(:run_command).with(shell_id, cmd, args).yields(command_id)
    service.stubs(:get_command_output).with(shell_id, command_id, &block).
      yields(output.stdout, output.stderr).returns(output)
  end

  def stub_powershell_script(shell_id, script, output, command_id = nil)
    stub_cmd(
      shell_id,
      "powershell",
      ["-encodedCommand", ::WinRM::PowershellScript.new(script).encoded],
      output,
      command_id
    )
  end
  # rubocop:enable Metrics/ParameterLists
end
