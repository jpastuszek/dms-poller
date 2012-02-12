probe(:stat) do
	File.open('/proc/stat') do |stat_file|
		stat_file.each_line do |line|
			case line
			when /^cpu/
				fields = line.split(' ')
				cpu = fields.shift
				values = fields
				Hash[[:user, :nice, :system, :idle, :iowait, :irq, :softirq, :steal, :virtual].zip(values)].each_pair do |component, value|
					collect 'CPU usage', cpu == 'cpu' ? 'total' : cpu.scan(/\d+/).first, component, value.to_i if value
				end
			when /^intr /
				fields = line.split(' ')
				total = fields.shift(2).last.to_i
				collect 'interrupt requests', 'hardware/total', 'count', total

				fields.map{|i| i.to_i}.each_with_index do |value, intr_no|
					collect 'interrupt requests', "hardware/#{intr_no.to_s}", 'count', value if value != 0
				end
			when /^softirq /
				fields = line.split(' ')
				total = fields.shift(2).last.to_i
				collect 'interrupt requests', 'software/total', 'count', total

				fields.map{|i| i.to_i}.each_with_index do |value, intr_no|
					collect 'interrupt requests', "software/#{intr_no.to_s}", 'count', value if value != 0
				end
			when /^ctxt /
				collect 'context switches', 'total', 'count', line.split(' ').last.to_i
			when /^btime /
				collect 'uptime', 'system', 'seconds', Time.now.to_i - line.split(' ').last.to_i
			when /^processes /
				collect 'processes', 'system', 'created', line.split(' ').last.to_i
			when /^procs_running /
				collect 'processes', 'system', 'running', line.split(' ').last.to_i
			when /^procs_blocked /
				collect 'processes', 'system', 'blocked', line.split(' ').last.to_i
			else
				log.warn "unsupported line: #{line}"
			end
		end
	end
end.schedule_every 10.second

probe(:meminfo) do
	File.open('/proc/meminfo') do |mem_file|
		mem_file.each_line do |line|
			title, value = line.split(/: */)
			value, unit = value.split(' ')

			value = value.to_i
			value = case unit
			when nil
				value
			when 'kB'
				value * 1024 # ?
			when 'mB'
				value * 1024 ** 2
			else
				log.warn "unsupported uint: #{unit}"
			end

			collect 'memory', 'system', title, value
		end
	end
end.schedule_every 30.seconds

