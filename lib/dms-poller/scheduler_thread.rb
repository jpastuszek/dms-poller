require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, collector_bind_address, quantum = 1, runs = nil, time_scale = 1.0, startup_run = false, process_limit = 8, process_time_out = 120.0)
		quantum *= time_scale

		log.info "using scheduler quantum of #{quantum} seconds"
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"
		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		log.info "running #{runs} runs" if runs

		all_probes = []
		scheduler = PeriodicScheduler.new(quantum)

		# program scheduler
		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				schedule = probe.schedule * time_scale 

				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{schedule} seconds"

				scheduler.schedule(schedule, true) do
					probe
				end

				all_probes << probe
			end
		end

		# start thread
		super do
			abort_on_exception = true

			ProcessPool.new(process_limit) do |process_pool|
				cycle(runs) do |run_no|
					probes = if startup_run and run_no == 1
						all_probes	
					else
						scheduler.run do |error|
							log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
						end
					end

					begin
						process_pool.process(process_time_out) do |process|
							process.on_timeout do |time_out|
								log.fatal "scheduler run process execution timed-out with limit of #{time_out} seconds"
							end
							logging_context("#{run_no}|#{Process.pid}")

							ZeroMQ.new do |zmq|
								zmq.push_connect(collector_bind_address) do |collector|
									probes.each_with_index do |probe, probe_no|
										log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{probes.length})"

										probe.run.each do |raw_datum|
											collector.send raw_datum
										end
									end
								end
							end
						end
					rescue ProcessPool::ProcessLimitReachedError => e
						log.warn "maximum number of scheduler run processes reached: limit: #{e.process_limit}: running pids: #{e.running_pids}"
					end
				end
			end
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

