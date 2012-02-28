Feature: Poller should collect RawDataPoint from running probes
	In order for dms-poller to produce RawDataPoints
	It has to collect RawDataPoint from running probes


	Background:
		Given dms-poller program
		And time scale 0.01
		And use startup run
		And debug enabled
		And bind collector at ipc:///tmp/dms-poller-collector-test
		And connect with data processor at tcp://127.0.0.1:12100
		Given poller module directory basic containing module system:
		"""
		probe('sysstat') do
			collect 'CPU usage/total', 'idle', 3123
			collect 'system/process', 'blocked', 0
		end.schedule_every 10.second

		probe('memory') do
			collect 'system/memory', 'total', 8182644
			collect 'system/memory', 'free', 5577396
		end.schedule_every 30.seconds
		"""

	@test
	Scenario: Poller run produced RawDataPoint objects at data processor that result in pooling runs
		Given data processor stub running at tcp://127.0.0.1:12100 that expects 12 messages
		Given using poller modules directory basic
		When it is started for 4 runs
		Then exit status will be 0
		And data processor will exit with 0
		And data processor output should include ':CPU usage/total/idle]: 3123' 4 times
		And data processor output should include ':system/memory/total]: 8182644' 2 times
		And data processor output should include ':system/memory/free]: 5577396' 2 times
		And data processor output should include 'RawDataPoint' 12 times
		And data processor output should include local host name 12 times

