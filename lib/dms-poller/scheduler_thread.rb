require 'periodic-scheduler'

class SchedulerThread < Thread
	def initialize(poller_modules, collector_bind_address, quantum, time_scale, runs, startup_run, process_limit, process_time_out)
		log.info "using scheduler quantum of #{quantum} seconds"
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"
		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		log.info "running #{runs} runs" if runs

		# start thread
		super do
			abort_on_exception = true

			ProcessPool.new(process_limit) do |process_pool|
				probe_scheduler(poller_modules, quantum, time_scale, runs, startup_run) do |probes, run_no|
					begin
						# fork process
						process_pool.process(process_time_out) do |process|
							process.on_timeout do |time_out|
								log.fatal "scheduler run process execution timed-out with limit of #{time_out} seconds"
							end
							logging_context("#{run_no}|#{Process.pid}")

							bind_collector(collector_bind_address) do |collector|
								run_probes(probes, run_no) do |raw_datum|
									collector.send raw_datum
								end
							end
						end
					rescue ProcessPool::ProcessLimitReachedError => e
						log.warn "maximum number of scheduler run processes reached: limit: #{e.process_limit}: running pids: #{e.running_pids}"
					end
				end

				log.info "scheduler finished #{runs} runs, shutting down..."

				pids = process_pool.running_pids
				log.info "watining for #{pids.length} scheduler run processes to finish: pids: #{pids.join(', ')}" unless pids.empty?
			end
		end
	end

	def probe_scheduler(poller_modules, quantum, time_scale, runs, startup_run)
		all_probes = []
		scheduler = PeriodicScheduler.new(quantum)

		# program scheduler
		poller_modules.each_pair do |poller_module_name, poller_module|
			poller_module.each_pair do |probe_name, probe|
				all_probes << probe

				schedule = probe.schedule * time_scale 
				log.info "scheduling probe #{poller_module_name}/#{probe_name} to run every #{schedule} seconds"
				scheduler.schedule(schedule, true) do
					probe
				end
			end
		end

		cycle(runs) do |run_no|
			probes = if startup_run and run_no == 1
				all_probes	
			else
				scheduler.run do |error|
					log.error "scheduler runtime error: #{error.class.name}: #{error.message}"
				end
			end

			yield probes, run_no
		end
	end

	def cycle(runs = nil)
		run_no = 1
		until runs and run_no > runs
			yield run_no
			run_no += 1
		end
	end

	def bind_collector(bind_address)
		ZeroMQ.new do |zmq|
			zmq.push_connect(bind_address) do |collector|
				yield collector
			end
		end
	end

	def run_probes(probes, run_no)
		probes.each_with_index do |probe, probe_no|
			log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{probes.length})"

			probe.run.each do |raw_datum|
				yield raw_datum
			end
		end
	end
end

