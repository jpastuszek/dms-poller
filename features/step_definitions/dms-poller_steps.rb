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

Given /using poller modules directory (.+)/ do |module_dir|
	raise "module dir #{module_dir} not defined!" unless @module_dirs.member? module_dir
	step "dms-poller program argument --module-dir #{@module_dirs[module_dir].to_s}"
end

Given /time scale (.+)/ do |time_scale|
	step "dms-poller program argument --time-scale #{time_scale}"
end

Given /use startup run/ do
	step "dms-poller program argument --startup-run"
end

Given /scheduler run process limit of (.+)/ do |limit|
	step "dms-poller program argument --process-limit #{limit.to_i}"
end

Given /scheduler run process time-out of (.+)/ do |timeout|
	step "dms-poller program argument --process-time-out #{timeout.to_f}"
end

And /bind collector at (.+)/ do |bind_address|
	step "dms-poller program argument --collector-bind-address #{bind_address}"
end

And /connect with data processor at (.+)/ do |data_processor_address|
	@data_processor_address = data_processor_address
	step "dms-poller program argument --data-processor-address #{data_processor_address}"
end

Given /it is started$/ do
	step 'dms-poller program is spawned'
end

Given /it is started for (.+) runs/ do |runs|
	step "dms-poller program argument --runs #{runs.to_i}"
	step 'it is started'
end

When /I wait it exits/ do
	 step 'I wait for dms-poller program termination'
end

Then /terminate the process/ do
	step "dms-poller program is terminated"
end

Then /exit status will be (.+)/ do |status|
	step "dms-poller program exit status should be #{status}"
end

Then /log output should not include '(.+)'/ do |entry|
	step "dms-poller program output should not include '#{entry}'"
end

Then /log output should include '(.+)' (.+) time/ do |entry, times|
	step "dms-poller program output should include '#{entry}' #{times} time"
end

Then /last log line should include '(.+)'/ do |entry|
	step "dms-poller program last output line should include '#{entry}'"
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

