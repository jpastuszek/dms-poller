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

Given /dms-poller is using poller modules directory (.+)/ do |module_dir|
	raise "module dir #{module_dir} not defined!" unless @module_dirs.member? module_dir
	step "dms-poller argument --module-dir #{@module_dirs[module_dir].to_s}"
end

Given /dms-poller is using time scale of (.+)/ do |time_scale|
	step "dms-poller argument --time-scale #{time_scale}"
end

Given /dms-poller is using startup run/ do
	step "dms-poller argument --startup-run"
end

Given /dms-poller scheduler process limit is set to (.+)/ do |limit|
	step "dms-poller argument --process-limit #{limit.to_i}"
end

Given /dms-poller scheduler run process time-out of (.+)/ do |timeout|
	step "dms-poller argument --process-time-out #{timeout.to_f}"
end

Given /dms-poller binds with collector at (.+)/ do |bind_address|
	step "dms-poller argument --collector-bind-address #{bind_address}"
end

Given /dms-poller connects with data processor at (.+)/ do |data_processor_address|
	@data_processor_address = data_processor_address
	step "dms-poller argument --data-processor-address #{data_processor_address}"
end

Given /dms-poller is started for (.+) runs/ do |runs|
	step "dms-poller argument --runs #{runs.to_i}"
	step 'dms-poller is spawned'
end

When /I wait dms-poller to exit/ do
	 step 'I wait for dms-poller termination'
end

Then /dms-poller exit status will be (.+)/ do |status|
	step "dms-poller exit status should be #{status}"
end

Then /dms-poller log should not include '(.+)'/ do |entry|
	step "dms-poller output should not include '#{entry}'"
end

Then /dms-poller log should include '(.+)' (.+) time/ do |entry, times|
	step "dms-poller output should include '#{entry}' #{times} time"
end

Then /dms-poller last log line should include '(.+)'/ do |entry|
	step "dms-poller last output line should include '#{entry}'"
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

