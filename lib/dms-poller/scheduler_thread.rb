require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, quantum = 1, scheduler_options = {})
		@scheduler = PeriodicScheduler.new(quantum, scheduler_options)
		@probes = []

		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{probe.schedule} seconds"
				@scheduler.schedule(probe.schedule, true) do
					@probes << probe
				end
			end
		end

		super do
			abort_on_exception = true

			loop do
				@probes.clear

				errors = @scheduler.run

				errors.each do |error|
					log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
				end
				
				run_probes(@probes)
			end
		end
	end

	def run_probes(probes)
		@probes.each_with_index do |probe, probe_no|
			log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{@probes.length})"
			raw_datum = probe.run

			if log.debug?
				raw_datum.each do |rd|
					log.debug "got RawDatum: #{rd.inspect}"
				end
			end
		end
	end
end

