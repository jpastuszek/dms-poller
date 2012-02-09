require 'periodic-scheduler'
require 'dms-poller/process_pool'

class SchedulerThread < Thread
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

	class SchedulerRunProcessPool < ProcessPool
		class SchedulerRunProcess
			def initialize(probes, bind_address, run_no)
				@probes = probes
				@bind_address = bind_address
				logging_context("#{run_no}|#{::Process.pid}")
			end

			def run
				begin
					bind_collector do |collector|
						run_probes do |raw_datum|
							collector.send raw_datum
						end
					end
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

			private

			def bind_collector
				ZeroMQ.new do |zmq|
					zmq.push_connect(@bind_address) do |collector|
						yield collector
					end
				end
			end

			def run_probes
				@probes.each_with_index do |probe, probe_no|
					log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{@probes.length})"

					probe.run.each do |raw_datum|
						yield raw_datum
					end
				end
			end
		end

		def fork_process(probes, collector_bind_address, process_time_out, run_no)
			begin
				process(process_time_out) do |process|
					scheduler_run_process = SchedulerRunProcess.new(probes, collector_bind_address, run_no)
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

	def initialize(poller_modules, collector_bind_address, quantum, time_scale, runs, startup_run, process_limit, process_time_out)
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"

		probe_scheduler = ProbeScheduler.new(quantum, time_scale)
		probe_scheduler.schedule_modules(poller_modules)

		# start thread
		super do
			abort_on_exception = true

			SchedulerRunProcessPool.new(process_limit) do |process_pool|
				probe_scheduler.run!(runs, startup_run) do |probes, run_no|
					process_pool.fork_process(probes, collector_bind_address, process_time_out, run_no)
				end

				log.info "scheduler finished #{runs} runs, shutting down..."

				pids = process_pool.running_pids
				log.info "watining for #{pids.length} scheduler run processes to finish: pids: #{pids.join(', ')}" unless pids.empty?
			end
		end
	end
end

