Feature: Poller startup and testing features
  In order to being able to test dms-poller executatble
  It has to support running specified number of cycles
  and with time scaling

  Scenario: Poller startup with 0 cycles
    Given dms-poller started in debug with -c 0
    When it exits
	Then exit status will be 0
	And log output will contain
	"""
	DMS Poller version 
	"""
	And log output will contain
	"""
	running 0 cycles
	"""
	And log output will not contain
	"""
	running probe
	"""
