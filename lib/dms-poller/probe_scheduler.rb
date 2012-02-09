class ProbeScheduler
	def initialize(quantum, time_scale)
		log.info "using scheduler quantum of #{quantum} seconds"
		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		@all_probes = []
		@time_scale = time_scale
		@scheduler = PeriodicScheduler.new(quantum)
	end

	def schedule_modules(poller_modules)
		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				@all_probes << probe

				schedule = probe.schedule * @time_scale 
				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{schedule} seconds"
				@scheduler.schedule(schedule, true) do
					probe
				end
			end
		end
	end

	def run!(runs, startup_run)
		log.info "running #{runs} runs" if runs
		cycle(runs) do |run_no|
			probes = if startup_run and run_no == 1
				@all_probes	
			else
				@scheduler.run do |error|
					log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
				end
			end

			yield probes, run_no
		end
	end

	private

	def cycle(runs = nil)
		run_no = 1
		until runs and run_no > runs
			yield run_no
			run_no += 1
		end
	end
end

