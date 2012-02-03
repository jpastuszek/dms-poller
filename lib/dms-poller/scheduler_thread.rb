require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, quantum = 1, scheduler_options = {})
		@scheduler = PeriodicScheduler.new(quantum, scheduler_options)

		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{probe.schedule} seconds"
				@scheduler.schedule(probe.schedule, true) do
					probe
				end
			end
		end

		super do
			abort_on_exception = true

			@scheduler.run! do |error|
				log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
			end
		end
	end
end

