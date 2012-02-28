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

require 'dms-poller/processing_thread'
require 'dms-poller/scheduler_run_process_pool'
require 'dms-poller/probe_scheduler'

class SchedulerThread < ProcessingThread
	def initialize(shutdown_queue, probes, location, collector_bind_address, quantum, time_scale, runs, startup_run, process_limit, process_time_out)
		probe_scheduler = ProbeScheduler.new(quantum, time_scale)
		probe_scheduler.schedule_probes(probes)

		super(shutdown_queue) do
			SchedulerRunProcessPool.new(process_limit, process_time_out) do |process_pool|
				begin
					probe_scheduler.run!(runs, startup_run) do |probes, run_no|
						process_pool.fork_process(probes, location, collector_bind_address, run_no)
					end

					log.info "scheduler finished #{runs} runs, shutting down..."
				ensure
					pids = process_pool.running_pids
					log.info "watining for #{pids.length} scheduler run processes to finish: pids: #{pids.join(', ')}" unless pids.empty?
				end
			end
		end
	end
end

