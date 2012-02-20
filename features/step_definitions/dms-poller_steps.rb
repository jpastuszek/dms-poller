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

Given /data processor stub running at (.+) that expects (.+) messages/ do |data_processor_address, message_count|
	
	@data_processor_stub_pid, @data_processor_stdout_thread = spawn('dms-data-processor-stub', "--bind-address #{data_processor_address} --message-count #{message_count}")
end

And /data processor will exit with (.+)/ do |status|
	begin
		Timeout.timeout(2) do
			Process.waitpid(@data_processor_stub_pid)
			$?.exitstatus.should == status.to_i	
			@data_processor_stdout = @data_processor_stdout_thread.value
		end
	rescue Timeout::Error
		Process.kill('TERM', @data_processor_stub_pid)
		raise
	end
end

And /data processor output should include '(.+)' (.+) time/ do |entry, times|
	@data_processor_stdout.scan(entry).size.should == times.to_i
end

And /data processor output should include local host name (.+) time/ do |times|
	entry = Facter.fqdn
	@data_processor_stdout.scan(entry).size.should == times.to_i
end

Given /poller module directory (.+) containing module (.+):/ do |module_dir, module_name, module_content|
	@module_dirs ||= {}
	module_name = module_name.to_sym

	module_dir = @module_dirs[module_dir] ||= temp_dir("poller_module_#{module_dir}")

	(module_dir + "#{module_name}.rb").open('w') do |f|
		f.write(module_content)
	end
end

Given /(.+) program/ do |program|
	@program = program
	@program_args = []
end

Given /using poller modules directory (.+)/ do |module_dir|
	raise "module dir #{module_dir} not defined!" unless @module_dirs.member? module_dir
	@program_args << ['--module-dir', @module_dirs[module_dir].to_s]
end

Given /time scale (.+)/ do |time_scale|
	@program_args << ['--time-scale', time_scale]
end

Given /use startup run/ do
	@program_args << ['--startup-run']
end

Given /debug enabled/ do
	@program_args << ['--debug']
end

Given /scheduler run process limit of (.+)/ do |limit|
	@program_args << ['--process-limit', limit.to_i]
end

Given /scheduler run process time-out of (.+)/ do |timeout|
	@program_args << ['--process-time-out', timeout.to_f]
end

Given /use linger time of (.+)/ do |linger_time|
	@program_args << ['--linger-time', linger_time.to_i]
end

And /bind collector at (.+)/ do |bind_address|
	@program_args << ['--collector-bind-address', bind_address]
end

And /connect with data processor at (.+)/ do |data_processor_address|
	@program_args << ['--data-processor-address', data_processor_address]
end

When /it is started for (.+) runs/ do |runs|
	@program_args = @program_args.join(' ') + ' ' + "--runs #{runs.to_i}"

	puts "#{@program} #{@program_args}"
	@program_out, @program_log, @program_status = run(@program, @program_args)
	#p @program_out
	puts @program_log
	#p @program_status
end


Then /exit status will be (.+)/ do |status|
	@program_status.exitstatus.should == status.to_i	
end

Then /log output should include following entries:/ do |log_entries|
	log_entries.raw.flatten.each do |entry|
		@program_log.should include(entry)
	end
end

Then /log output should not include following entries:/ do |log_entries|
	log_entries.raw.flatten.each do |entry|
		@program_log.should_not include(entry)
	end
end

Then /log output should not include '(.+)'/ do |entry|
	@program_log.should_not include(entry)
end

Then /log output should include '(.+)' (.+) time/ do |entry, times|
	@program_log.scan(entry).size.should == times.to_i
end

Then /last log line should include '(.+)'/ do |entry|
	@program_log.lines.to_a.last.should include(entry)
end

