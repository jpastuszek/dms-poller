Feature: Poller should collect RawDatum from running probes
	In order for dms-poller to produce RawDataPoints
	It has to collect RawDatum from running probes


	Background:
		Given dms-poller program
		And time scale 0.01
		And use startup run
		And debug enabled
		And bind collector at ipc:///tmp/dms-poller-collector-test
		Given poller module directory basic containing module system:
		"""
		probe(:sysstat) do
			collect 'CPU usage', 'total', 'idle', 3123
			collect 'system', 'process', 'blocked', 0
		end.schedule_every 10.second

		probe(:memory) do
			collect 'system', '', 'total', 8182644
			collect 'system', '', 'free', 5577396
		end.schedule_every 30.seconds
		"""

	@test
	Scenario: Poller run produced RawDatum that is collected by collector thread
		Given using poller modules directory basic
		When it is started for 4 runs
		Then exit status will be 0
		And log output should include 'Binding collector socket at: ipc:///tmp/dms-poller-collector-test' 1 time
		And log output should include 'collected RawDatum[CPU usage/total/idle]: 3123' 4 times
		And log output should include 'collected RawDatum[system/process/blocked]: 0' 4 times
		And log output should include 'collected RawDatum[system//total]: 8182644' 2 times
		And log output should include 'collected RawDatum[system//free]: 5577396' 2 times

