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

When /it is started with arguments (.+)/ do |args|
	@program_args = @program_args.join(' ') + ' ' + args

	puts "#{@program} #{@program_args}"
	@program_out, @program_log, @program_status = run(@program, @program_args)
	#p @program_out
	#puts @program_log
	#p @program_status
end

When /it is started for (.+) run cycle/ do |cycles|
	@program_args = @program_args.join(' ') + ' ' + "--run-cycles #{cycles.to_i}"

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

Then /log output should include '(.+)' (.+) times/ do |entry, times|
	@program_log.scan(entry).size.should == times.to_i
end

