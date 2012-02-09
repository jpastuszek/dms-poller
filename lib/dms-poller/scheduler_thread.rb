require 'periodic-scheduler'
require 'dms-poller/scheduler_run_process_pool'
require 'dms-poller/probe_scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, collector_bind_address, quantum, time_scale, runs, startup_run, process_limit, process_time_out)
		probe_scheduler = ProbeScheduler.new(quantum, time_scale)
		probe_scheduler.schedule_modules(poller_modules)

		# start thread
		super do
			abort_on_exception = true
			SchedulerRunProcessPool.new(process_limit, process_time_out) do |process_pool|
				probe_scheduler.run!(runs, startup_run) do |probes, run_no|
					process_pool.fork_process(probes, collector_bind_address, run_no)
				end

				log.info "scheduler finished #{runs} runs, shutting down..."

				pids = process_pool.running_pids
				log.info "watining for #{pids.length} scheduler run processes to finish: pids: #{pids.join(', ')}" unless pids.empty?
			end
		end
	end
end

