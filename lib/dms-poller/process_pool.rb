# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

class ProcessPool
	class Process
		class ProcessHelper
			def initialize(time_out)
				@time_out = time_out
			end

			attr_reader :time_out

			def on_timeout(&block)
				@on_timeout = block
			end

			def handle_timeout
				@on_timeout.call(@time_out) if @on_timeout
			end
		end

		def initialize(time_out)
			@time_out = time_out
			@pid = fork do
				helper = ProcessHelper.new(@time_out)

				begin
					Timeout::timeout(@time_out) do
						yield helper
					end
				rescue Timeout::Error
					helper.handle_timeout
					exit!(201)
				rescue Interrupt
					exit!(202)
				rescue => e
					exit!(200)
				end

				exit!(0)
			end

			@thread = ::Process.detach(@pid)
		end

		attr_reader :pid
		attr_reader :time_out

		def join
			@thread.join
		end

		def exitstatus
			@thread.value.exitstatus
		end

		def running?
			@thread.alive?
		end
	end

	class ProcessLimitReachedError < RuntimeError
		def initialize(process_limit, running_pids)
			@process_limit = process_limit
			@running_pids = running_pids
			super "maximum number of processes reached: limit: #{process_limit}: running process pids: #{running_pids.join(', ')}"
		end

		attr_reader :process_limit
		attr_reader :running_pids
	end

	def initialize(process_limit = 8)
		@process_limit = process_limit
		@processes = []

		begin
			yield self
		ensure
			wait
		end
	end

	attr_reader :process_limit

	def process(time_out = 10, &block)
		pids = running_pids

		raise ProcessLimitReachedError.new(@process_limit, pids) if pids.length >= @process_limit

		process = Process.new(time_out, &block)
		@processes << process
		process
	end

	def running_pids
		@processes.delete_if{|process| not process.running?}
		@processes.map{|p| p.pid}
	end

	private

	def wait
		pids = running_pids

		@processes.each do |process|
			process.join
		end
	end
end

