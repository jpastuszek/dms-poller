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

Given /poller module directory (.+) containing module (.+):/ do |module_dir, module_name, module_content|
	@module_dirs ||= {}
	module_name = module_name.to_sym

	module_dir = @module_dirs[module_dir] ||= temp_dir("poller_module_#{module_dir}")

	(module_dir + "#{module_name}.rb").open('w') do |f|
		f.write(module_content)
	end
end

Given /([^ ]*) is using poller modules directory (.+)/ do |program, module_dir|
	raise "module dir #{module_dir} not defined!" unless @module_dirs.member? module_dir
	step "#{program} argument --module-dir #{@module_dirs[module_dir].to_s}"
end

Given /([^ ]*) is using time scale of (.+)/ do |program, time_scale|
	step "#{program} argument --time-scale #{time_scale}"
end

Given /([^ ]*) is using startup run/ do |program|
	step "#{program} argument --startup-run"
end

Given /([^ ]*) scheduler process limit is set to (.+)/ do |program, limit|
	step "#{program} argument --process-limit #{limit.to_i}"
end

Given /([^ ]*) scheduler run process time-out of (.+)/ do |program, timeout|
	step "#{program} argument --process-time-out #{timeout.to_f}"
end

Given /([^ ]*) binds with collector at (.+)/ do |program, bind_address|
	step "#{program} argument --collector-bind-address #{bind_address}"
end

Given /([^ ]*) connects with data processor at (.+)/ do |program, data_processor_address|
	@data_processor_address = data_processor_address
	step "#{program} argument --data-processor-address #{data_processor_address}"
end

Given /([^ ]*) is started for (.+) runs/ do |program, runs|
	step "#{program} argument --runs #{runs.to_i}"
	step "#{program} is spawned"
end

Then /([^ ]*) log should not include '(.+)'/ do |program, entry|
	step "#{program} output should not include '#{entry}'"
end

Then /([^ ]*) log should include '(.+)' (.+) time/ do |program, entry, times|
	step "#{program} output should include '#{entry}' #{times} time"
end

Then /([^ ]*) last log line should include '(.+)'/ do |program, entry|
	step "#{program} last output line should include '#{entry}'"
end

Then /data processor should receive following RawDataPoints:/ do |raw_data_points|
	Timeout.timeout 4 do
		ZeroMQ.new do |zmq|
			zmq.pull_bind(@data_processor_address) do |pull|
				message = nil
				pull.on RawDataPoint do |msg|
					message = msg
				end

				raw_data_points.hashes.each do |h|
					message = nil
					pull.receive!
					message.path.should == h[:path]
					message.component.should == h[:component]
					message.value.should == h[:value].to_i
				end
			end
		end
	end
end

