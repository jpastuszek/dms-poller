class SchedulerRunProcess
	def initialize(cycle_no, probes)
		pid = fork do
			probes.each_with_index do |probe, probe_no|
				log.debug "#{cycle_no}, #{probe_no + 1}/#{probes.length}: running probe: #{probe.module_name}/#{probe.probe_name}"

				raw_datum = probe.run
			end

			exit!(0)
		end

		@pid = pid
		@thread = Process.detach(pid)
	end

	attr_reader :pid

	def join
		@thread.join
	end

	def running?
		@thread.alive?
	end
end

class SchedulerRunProcessPool
	def initialize
		@processes = []
	end

	def start(cycle_no, probes)
		cleanup

		@processes << SchedulerRunProcess.new(cycle_no, probes)
	end

	def wait
		cleanup

		log.info "awaiting for #{@processes.length} scheduler run processes to finish, pids: #{@processes.map{|p| p.pid}.join(', ')}" unless @processes.empty?
		@processes.each do |process|
			process.join
		end
	end

	private

	def cleanup
		@processes.delete_if{|process| not process.running?}
	end
end

