Feature: Poller should run probes in isolated environment
	In order for dms-poller to meet its schedules
	It has to run probes in isolated environment

	Background:
		Given dms-poller program
		And time scale 0.01
		And use startup run
		And debug enabled
		Given poller module directory broken containing module system:
		"""
		probe(:sysstat) do
			collect 'CPU usage', 'total', 'idle', 3123
			raise 'test error'
			collect 'system', 'process', 'blocked', 0
		end.schedule_every 10.second
		"""
		Given poller module directory slow containing module system:
		"""
		probe(:sysstat) do
			collect 'CPU usage', 'total', 'idle', 3123
			sleep 0.2
			collect 'system', 'process', 'blocked', 0
		end.schedule_every 10.second
		"""

	@test1
	Scenario: It should not crash on errors from probes and should log them
		Given using poller modules directory broken
		When it is started for 3 run cycle
		Then exit status will be 0
		And log output should include 'running probe: system/sysstat' 3 times
		And log output should include 'Probe system/sysstat raised error: RuntimeError: test error' 3 times

	@test
	Scenario: It should wait all running probes to finish before exiting
		Given using poller modules directory slow
		When it is started for 2 run cycle
		Then exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		And last log line should include 'scheduler finished execution, exiting'

	@test
	Scenario: Slow running probe should not delay the scheduler
		Given using poller modules directory slow
		When it is started for 2 run cycle
		Then exit status will be 0
		And log output should include 'running probe: system/sysstat' 2 times
		But log output should not include 'missed schedule'
		And last log line should include 'scheduler finished execution, exiting'
