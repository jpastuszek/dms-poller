Given /(.+) program/ do |program|
	@program = program
end

When /it is started in debug with arguments (.+)/ do |args|
	@program_args = args

	@program_out, @program_log, @program_status = run(@program, @program_args, true)
#	p @program_out
#	p @program_log
#	p @program_status
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

Then /log output should include \"(.+)\" (.+)/ do |entry, times|
	@program_log.scan(entry).size.should == times.to_i
end

