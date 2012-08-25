Feature: Poller should run probes in isolated environment
	In order for dms-poller to meet its schedules
	It has to run probes in isolated environment

	Background:
		Given time scale 0.01
		And use startup run
		And dms-poller program use linger time of 0
		And dms-poller program debug enabled
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
		Given using poller modules directory broken
		Given it is started for 3 runs
		Then I wait it exits
		And exit status will be 0
		And log output should include 'running probe: system/sysstat' 3 times
		And log output should include 'probe system/sysstat raised error: RuntimeError: test error' 3 times

	Scenario: It should wait all running probes to finish before exiting
		Given using poller modules directory slow
		Given it is started for 2 runs
		Then I wait it exits
		And exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		And last log line should include 'DMS Poller done'

	Scenario: Slow running probe should not delay the scheduler
		Given using poller modules directory slow
		Given it is started for 2 runs
		Then I wait it exits
		And exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		But log output should not include 'missed schedule'
		And last log line should include 'DMS Poller done'

	Scenario: Scheduler should not allow running more than desired maximum number of processes in parallel
		Given using poller modules directory stale
		And scheduler run process limit of 2
		Given it is started for 4 runs
		Then I wait it exits
		And exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		And log output should include 'maximum number of scheduler run processes reached' 2 times
		But log output should not include 'missed schedule'
		And last log line should include 'DMS Poller done'

	@timeout
	Scenario: Scheduler run process should time-out its execution after specified maximum time
		Given using poller modules directory stale
		And scheduler run process time-out of 0.5 seconds
		Given it is started for 2 runs
		Then I wait it exits
		And exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		And log output should include 'execution timed-out with limit of 0.5 seconds' 2 times
		But log output should not include 'missed schedule'
		And last log line should include 'DMS Poller done'

