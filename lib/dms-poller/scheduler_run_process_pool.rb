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

require 'dms-poller/process_pool'

class SchedulerRunProcessPool < ProcessPool
	class SchedulerRunProcess
		def initialize(probes, location, bind_address, run_no)
			@probes = probes
			@location = location
			@bind_address = bind_address
			logging_context("#{run_no}|#{::Process.pid}")
		end

		def run
			begin
				ZeroMQ.new do |zmq|
					zmq.push_connect(@bind_address) do |push|
						@probes.each_with_index do |probe, probe_no|
							log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{@probes.length})"

							probe.run(@location) do |raw_data_point|
								log.debug "sending #{raw_data_point}"
								push.send raw_data_point
							end
						end
					end
				end
				log.debug "done"
			rescue => e
				log.fatal "got error: #{e}: #{e.message}: #{e.backtrace.join("\n")}\nexiting"
				exit!(3)
			rescue Interrupt
				log.info "interrupted, exiting"
				exit!(1)
			end
		end

		def timed_out(time_out)
			log.fatal "execution timed-out with limit of #{time_out} seconds"
			exit!(2)
		end
	end

	def initialize(process_limit, process_time_out)
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"
		@process_time_out = process_time_out
		super(process_limit)
	end

	def fork_process(probes, location, collector_bind_address, run_no)
		begin
			process(@process_time_out) do |process|
				scheduler_run_process = SchedulerRunProcess.new(probes, location, collector_bind_address, run_no)
				process.on_timeout do |time_out|
					scheduler_run_process.timed_out(time_out)
				end
				scheduler_run_process.run
			end
		rescue ProcessPool::ProcessLimitReachedError => e
			log.warn "maximum number of scheduler run processes reached: limit: #{e.process_limit}: running pids: #{e.running_pids}"
		end
	end
end

