# -*- encoding: utf-8 -*-
#
# Author:: Matt Wrock (<matt@mattwrock.com>)
#
# Copyright (C) 2014, Matt Wrock
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

require "winrm/transport/logging"

module WinRM

  module Transport

    # Object which can execute multiple commands and Powershell scripts in
    # one shared remote shell session. The maximum number of commands per
    # shell is determined by interrogating the remote host when the session
    # is opened and the remote shell is automatically recycled before the
    # threshold is reached.
    #
    # @author Matt Wrock <matt@mattwrock.com>
    # @author Fletcher Nichol <fnichol@nichol.ca>
    class CommandExecutor

      include Logging

      # @return [Integer,nil] the safe maximum number of commands that can
      #   be executed in one remote shell session, or `nil` if the
      #   threshold has not yet been determined
      attr_reader :max_commands

      # @return [String,nil] the identifier for the current open remote
      #   shell session, or `nil` if the session is not open
      attr_reader :shell

      # Creates a CommandExecutor given a `WinRM::WinRMWebService` object.
      #
      # @param service [WinRM::WinRMWebService] a winrm web service object
      # @param logger [#debug,#info] an optional logger/ui object that
      #   responds to `#debug` and `#info` (default: `nil`)
      # @param closer [ShellCloser] an optional object to automatically
      #   close the active open remote shell when CommandExecutor garbarge
      #   collects
      def initialize(service, logger = nil, closer = nil)
        @service        = service
        @logger         = logger
        @closer         = closer
        @command_count  = 0
      end

      # Closes the open remote shell session. This method can be called
      # multiple times, even if there is no open session.
      def close
        return if shell.nil?

        service.close_shell(shell)
        remove_finalizer
        @shell = nil
      end

      # Opens a remote shell session for reuse. The maxiumum
      # command-per-shell threshold is also determined the first time this
      # method is invoked and cached for later invocations.
      #
      # @return [String] the remote shell session indentifier
      def open
        close

        attempt = 0
        begin
          @shell = service.open_shell
        rescue WinRMWSManFault => e
          fault = "Illegal operation attempted on a registry key that has been marked for deletion"
          raise unless e.fault_description.include?(fault) && attempt < MAX_RETRIES
          debug {
            "Retry open_shell: fault_code=#{e.fault_code};fault_description=#{e.fault_description}"
          }

          attempt += 1
          debug { "sleeping #{SLEEP_SECONDS} seconds before retry" }
          sleep SLEEP_SECONDS
          retry
        end

        add_finalizer(shell)
        @command_count = 0
        determine_max_commands unless max_commands
        shell
      end

      # Runs a CMD command.
      #
      # @param command [String] the command to run on the remote system
      # @param arguments [Array<String>] arguments to the command
      # @yield [stdout, stderr] yields more live access the standard
      #   output and standard error streams as they are returns, if
      #   streaming behavior is desired
      # @return [WinRM::Output] output object with stdout, stderr, and
      #   exit code
      def run_cmd(command, arguments = [], &block)
        reset if command_count_exceeded?
        ensure_open_shell!

        @command_count += 1
        result = nil
        service.run_command(shell, command, arguments) do |command_id|
          result = service.get_command_output(shell, command_id, &block)
        end
        result
      end

      # Run a Powershell script that resides on the local box.
      #
      # @param script_file [IO,String] an IO reference for reading the
      #   Powershell script or the actual file contents
      # @yield [stdout, stderr] yields more live access the standard
      #   output and standard error streams as they are returns, if
      #   streaming behavior is desired
      # @return [WinRM::Output] output object with stdout, stderr, and
      #   exit code
      def run_powershell_script(script_file, &block)
        # this code looks overly compact in an attempt to limit local
        # variable assignments that may contain large strings and
        # consequently bloat the Ruby VM
        run_cmd(
          "powershell",
          [
            "-encodedCommand",
            ::WinRM::PowershellScript.new(
              script_file.is_a?(IO) ? script_file.read : script_file
            ).encoded
          ],
          &block
        )
      end

      private

      # @return [Integer] the default maximum number of commands which can be
      #   executed in one remote shell session on "older" versions of Windows
      # @api private
      LEGACY_LIMIT = 15

      # @return [Integer] the default maximum number of commands which can be
      #   executed in one remote shell session on "modern" versions of Windows
      # @api private
      MODERN_LIMIT = 1500

      # @return [Integer] the maximum number of times to retry if certain faults
      #   occur when attempting to open a remote shell session
      # @api private
      MAX_RETRIES = 4

      # @return [Integer] then number of seconds to wait before retrying when
      #   attempting to to open a remote shell session after a fault
      # @api private
      SLEEP_SECONDS = 2

      # @return [String] the PowerShell command used to determine the version
      #   of Windows
      # @api private
      PS1_OS_VERSION = "[environment]::OSVersion.Version.tostring()".freeze

      # @return [Integer] the number of executed commands on the remote
      #   shell session
      # @api private
      attr_accessor :command_count

      # @return [#debug,#info] the logger
      # @api private
      attr_reader :logger

      # @return [WinRM::WinRMWebService] a WinRM web service object
      # @api private
      attr_reader :service

      # Creates a finalizer for this connection which will close the open
      # remote shell session when the object is garabage collected or on
      # Ruby VM shutdown.
      #
      # @param shell_id [String] the remote shell identifier
      # @api private
      def add_finalizer(shell_id)
        ObjectSpace.define_finalizer(self, @closer.for(shell_id)) if @closer
      end

      # @return [true,false] whether or not the number of exeecuted commands
      #   have exceeded the maxiumum threshold
      # @api private
      def command_count_exceeded?
        command_count > max_commands.to_i
      end

      # Ensures that there is an open remote shell session.
      #
      # @raise [WinRM::WinRMError] if there is no open shell
      # @api private
      def ensure_open_shell!
        if shell.nil?
          raise ::WinRM::WinRMError, "#{self.class}#open must be called " \
            "before any run methods are invoked"
        end
      end

      # Determines the safe maximum number of commands that can be executed
      # on a remote shell session by interrogating the remote host.
      #
      # @api private
      def determine_max_commands
        os_version = run_powershell_script(PS1_OS_VERSION).stdout.chomp
        @max_commands = os_version < "6.2" ? LEGACY_LIMIT : MODERN_LIMIT
        @max_commands -= 2 # to be safe
      end

      # Removes any finalizers for this connection.
      #
      # @api private
      def remove_finalizer
        ObjectSpace.undefine_finalizer(self) if @closer
      end

      # Closes the remote shell session and opens a new one.
      #
      # @api private
      def reset
        debug {
          "Resetting WinRM shell (Max command limit is #{max_commands})"
        }
        open
      end
    end
  end
end
