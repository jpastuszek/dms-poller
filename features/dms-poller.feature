Feature: Poller startup and testing features
	In order to be able to test dms-poller program
	It has to support running specified number of cycles
	And it has to run with time scaling so that test will run fast

	Background:
		Given dms-poller program
		And time scale 0.01
		And debug enabled
		Given poller module directory basic containing module system:
		"""
		probe(:sysstat) do
			collect 'CPU usage', 'total', 'idle', 3123
			collect 'system', 'process', 'blocked', 0
		end.schedule_every 10.second

		probe(:memory) do
			collect 'system', '', 'total', 8182644
			collect 'system', '', 'free', 5577396
			collect 'system', '', 'buffers', 254404
		end.schedule_every 30.seconds
		"""

	Scenario Outline: Poller run with different cycle count
		Given using poller modules directory basic
		When it is started with arguments -c <cycles>
		Then exit status will be 0
		And log output should include following entries:
			| Starting DMS Poller version |
			| DMS Poller ready |
			| running <cycles> cycles |
		And log output should include '<log line>' <times> times

		Examples:
			| cycles	| log line						| times	|
			| 0			| running probe: system/sysstat | 0		|
			| 1			| running probe: system/sysstat | 1		|
			| 3			| running probe: system/sysstat | 3		|
			| 3			| running probe: system/memory	| 1		|

