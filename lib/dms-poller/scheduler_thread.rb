require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, quantum = 1, runs = nil, time_scale = 1.0, startup_run = false, process_limit = 8, process_time_out = 120.0)
		quantum *= time_scale

		log.info "using scheduler quantum of #{quantum} seconds"
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"
		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		log.info "running #{runs} runs" if runs

		@scheduler_run_process_pool = SchedulerRunProcessPool.new(process_limit)

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

			cycle(runs) do |run_no|
				if @probes.empty? # skip for startup run
					errors = @scheduler.run
					errors.each do |error|
						log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
					end
				end

				begin
					@scheduler_run_process_pool.start(run_no, @probes, process_time_out)
				rescue SchedulerRunProcessPool::ProcessLimitReachedError => e
					log.warn "#{e.message}"
				end
				@probes.clear
			end
		end
	end

	def wait_run_processes
		@scheduler_run_process_pool.wait
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

