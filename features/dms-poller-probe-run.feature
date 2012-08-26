Feature: Poller should run probes in isolated environment
	In order for dms-poller to meet its schedules
	It has to run probes in isolated environment

	Background:
		Given dms-poller is using time scale of 0.01
		And dms-poller is using startup run
		And dms-poller is using linger time of 0
		And dms-poller has debug enabled
		Given poller module directory broken containing module system:
		"""
		probe('sysstat') do
			collect 'CPU usage/total', 'idle', 3123
			raise 'test error'
			collect 'system/process', 'blocked', 0
		end.schedule_every 10.second
		"""
		Given poller module directory slow containing module system:
		"""
		probe('sysstat') do
			collect 'CPU usage/total', 'idle', 3123
			sleep 0.2
			collect 'system/process', 'blocked', 0
		end.schedule_every 10.second
		"""
		Given poller module directory stale containing module system:
		"""
		probe('sysstat') do
			collect 'CPU usage/total', 'idle', 3123
			sleep 0.7
			collect 'system/process', 'blocked', 0
		end.schedule_every 5.second
		"""

	@broken
	Scenario: It should not crash on errors from probes and should log them
		Given dms-poller is using poller modules directory broken
		Given dms-poller is started for 3 runs
		When I wait dms-poller to exit
		Then dms-poller exit status will be 0
		And dms-poller log should include 'running probe: system/sysstat' 3 times
		And dms-poller log should include 'probe system/sysstat raised error: RuntimeError: test error' 3 times

	Scenario: It should wait all running probes to finish before exiting
		Given dms-poller is using poller modules directory slow
		Given dms-poller is started for 2 runs
		When I wait dms-poller to exit
		Then dms-poller exit status will be 0
		And dms-poller log should include 'running probe: system/sysstat' 2 times
		And dms-poller last log line should include 'DMS Poller done'

	Scenario: Slow running probe should not delay the scheduler
		Given dms-poller is using poller modules directory slow
		Given dms-poller is started for 2 runs
		When I wait dms-poller to exit
		Then dms-poller exit status will be 0
		And dms-poller log should include 'running probe: system/sysstat' 2 times
		But dms-poller log should not include 'missed schedule'
		And dms-poller last log line should include 'DMS Poller done'

	Scenario: Scheduler should not allow running more than desired maximum number of processes in parallel
		Given dms-poller is using poller modules directory stale
		And dms-poller scheduler process limit is set to 2
		Given dms-poller is started for 4 runs
		When I wait dms-poller to exit
		Then dms-poller exit status will be 0
		And dms-poller log should include 'running probe: system/sysstat' 2 times
		And dms-poller log should include 'maximum number of scheduler run processes reached' 2 times
		But dms-poller log should not include 'missed schedule'
		And dms-poller last log line should include 'DMS Poller done'

	@timeout
	Scenario: Scheduler run process should time-out its execution after specified maximum time
		Given dms-poller is using poller modules directory stale
		And dms-poller scheduler run process time-out of 0.5 seconds
		Given dms-poller is started for 2 runs
		When I wait dms-poller to exit
		Then dms-poller exit status will be 0
		And dms-poller log should include 'running probe: system/sysstat' 2 times
		And dms-poller log should include 'execution timed-out with limit of 0.5 seconds' 2 times
		But dms-poller log should not include 'missed schedule'
		And dms-poller last log line should include 'DMS Poller done'

