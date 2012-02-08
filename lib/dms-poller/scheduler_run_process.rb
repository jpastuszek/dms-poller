require 'timeout'

class SchedulerRunProcess
	def initialize(run_no, probes, collector_bind_address, process_time_out)
		@pid = fork do
			logging_context("#{run_no}|#{Process.pid}")
			begin
				Timeout::timeout(process_time_out) do
					ZeroMQ.new do |zmq|
						zmq.push_connect(collector_bind_address) do |collector|
							process_probes(probes, collector)
						end
					end
				end
			rescue Timeout::Error
				log.error "scheduler run process execution timed-out with limit of #{process_time_out} seconds"
				exit!(1)
			end

			exit!(0)
		end

		@thread = Process.detach(@pid)
	end

	attr_reader :pid

	def join
		@thread.join
	end

	def running?
		@thread.alive?
	end

	private

	def process_probes(probes, collector)
		probes.each_with_index do |probe, probe_no|
			log.debug "running probe: #{probe.module_name}/#{probe.probe_name} (#{probe_no + 1}/#{probes.length})"

			probe.run.each do |raw_datum|
				collector.send raw_datum
			end
		end
	end
end

class SchedulerRunProcessPool
	class ProcessLimitReachedError < RuntimeError
		def initialize(process_limit, pids)
			super "maximum number of scheduler run processes reached: limit: #{process_limit}: running process pids: #{pids.join(', ')}"
		end
	end

	def initialize(process_limit)
		@process_limit = process_limit
		@processes = []
	end

	def start(run_no, probes, collector_bind_address, process_time_out)
		cleanup

		raise ProcessLimitReachedError.new(@process_limit, pids) if @processes.length >= @process_limit

		@processes << SchedulerRunProcess.new(run_no, probes, collector_bind_address, process_time_out)
	end

	def wait
		cleanup

		log.info "waiting for #{@processes.length} scheduler run processes to finish, pids: #{pids.join(', ')}" unless @processes.empty?
		@processes.each do |process|
			process.join
		end
	end

	private

	def pids
		@processes.map{|p| p.pid}
	end

	def cleanup
		@processes.delete_if{|process| not process.running?}
	end
end

