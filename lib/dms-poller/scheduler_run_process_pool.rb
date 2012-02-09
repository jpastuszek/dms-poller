require 'dms-poller/process_pool'

class SchedulerRunProcessPool < ProcessPool
	class SchedulerRunProcess
		def initialize(probes, bind_address, run_no)
			@probes = probes
			@bind_address = bind_address
			logging_context("#{run_no}|#{::Process.pid}")
		end

		def run
			begin
				ZeroMQ.new do |zmq|
					zmq.push_connect(@bind_address) do |push|
						@probes.each_with_index do |probe, probe_no|
							log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{@probes.length})"

							probe.run.each do |raw_datum|
								log.debug "sending #{raw_datum}"
								push.send raw_datum
							end
						end
					end
				end
				log.debug "done"
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
	end

	def initialize(process_limit, process_time_out)
		log.info "scheduler run process limit set to #{process_limit}"
		log.info "scheduler run process time-out after #{process_time_out} seconds"
		@process_time_out = process_time_out
		super(process_limit)
	end

	def fork_process(probes, collector_bind_address, run_no)
		begin
			process(@process_time_out) do |process|
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

