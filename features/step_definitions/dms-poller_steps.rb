Given /dms-poller started in debug with (.*)/ do |args|
	@out, @log, @status = dms_poller(true, args)
end

