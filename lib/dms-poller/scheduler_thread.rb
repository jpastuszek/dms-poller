require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, quantum = 1, run_cycles = nil, time_scale = 1.0, startup_run = false)
		quantum *= time_scale

		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		log.info "using scheduler quantum of #{quantum} seconds"
		log.info "running #{run_cycles} cycles" if run_cycles

		@scheduler = PeriodicScheduler.new(quantum)
		@probes = []

		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				schedule = probe.schedule * time_scale 

				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{schedule} seconds"

				@probes << probe if startup_run
				@scheduler.schedule(schedule, true) do
					@probes << probe
				end
			end
		end

		super do
			abort_on_exception = true

			cycle(run_cycles) do |cycle_no|
				if @probes.empty? # skip for startup run
					errors = @scheduler.run
					errors.each do |error|
						log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
					end
				end

				run_probes(cycle_no, @probes)
				@probes.clear
			end
		end
	end

	def run_probes(cycle_no, probes)
		#TODO: quantum run process (fork)
		@probes.each_with_index do |probe, probe_no|
			log.debug "#{cycle_no}, #{probe_no + 1}/#{@probes.length}: running probe: #{probe.module_name}/#{probe.probe_name}"

			raw_datum = probe.run
		end
	end

	private

	def cycle(times = nil)
		cycle_no = 1
		until times and cycle_no > times
			yield cycle_no
			cycle_no += 1
		end
	end
end

