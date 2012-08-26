Feature: Poller should collect RawDataPoint from running probes
	In order for dms-poller to produce RawDataPoints
	It has to collect RawDataPoint from running probes


	Background:
		Given dms-poller is using time scale of 0.01
		And dms-poller is using startup run
		And dms-poller is using linger time of 2
		And dms-poller has debug enabled
		And dms-poller binds with collector at ipc:///tmp/dms-poller-collector-test
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
		Given dms-poller is using poller modules directory basic
		And dms-poller connects with data processor at ipc:///tmp/dms-poller-processor-test
		When dms-poller is running
		Then data processor should receive following RawDataPoints:
			| path				| component | value		|
			| CPU usage/total	| idle		| 3123		|
			| system/process	| blocked	| 0			|
			| system/memory		| total		| 8182644	|
			| system/memory		| free		| 5577396	|
			| CPU usage/total	| idle		| 3123		|
			| system/process	| blocked	| 0			|
			| CPU usage/total	| idle		| 3123		|
			| system/process	| blocked	| 0			|
			| system/memory		| total		| 8182644	|
			| system/memory		| free		| 5577396	|
			| CPU usage/total	| idle		| 3123		|
			| system/process	| blocked	| 0			|

