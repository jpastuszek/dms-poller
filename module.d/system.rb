# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

probe('stat') do
	File.open('/proc/stat') do |stat_file|
		stat_file.each_line do |line|
			case line
			when /^cpu/
				fields = line.split(' ')
				cpu = fields.shift
				values = fields
				Hash[[:user, :nice, :system, :idle, :iowait, :irq, :softirq, :steal, :virtual].zip(values)].each_pair do |component, value|
					collect "system/CPU usage/#{cpu == 'cpu' ? 'total' : 'CPU/' + cpu.scan(/\d+/).first}", component, value.to_i if value
				end
			when /^intr /
				fields = line.split(' ')
				total = fields.shift(2).last.to_i
				collect 'system/interrupt requests/hardware/total', 'count', total

				fields.map{|i| i.to_i}.each_with_index do |value, intr_no|
					collect "system/interrupt requests/hardware/#{intr_no.to_s}", 'count', value if value != 0
				end
			when /^softirq /
				fields = line.split(' ')
				total = fields.shift(2).last.to_i
				collect 'system/interrupt requests/software/total', 'count', total

				fields.map{|i| i.to_i}.each_with_index do |value, intr_no|
					collect "system/interrupt requests/software/#{intr_no.to_s}", 'count', value if value != 0
				end
			when /^ctxt /
				collect 'system/context switches/total', 'count', line.split(' ').last.to_i
			when /^btime /
				collect 'system/uptime', 'seconds', Time.now.to_i - line.split(' ').last.to_i
			when /^processes /
				collect 'system/processes', 'created', line.split(' ').last.to_i
			when /^procs_running /
				collect 'system/processes', 'running', line.split(' ').last.to_i
			when /^procs_blocked /
				collect 'system/processes', 'blocked', line.split(' ').last.to_i
			else
				log.warn "unsupported line: #{line}"
			end
		end
	end
end.schedule_every 10.second

probe('meminfo') do
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

			collect 'system/memory', title, value
		end
	end
end.schedule_every 30.seconds

