Feature: Poller startup and testing features
	In order to being able to test dms-poller executatble
	It has to support running specified number of cycles
	and with time scaling

	Scenario Outline: Poller startup with different cycle count (time scaled)
		Given dms-poller program
		When it is started in debug with arguments -c <cycles> -t 0.01
		Then exit status will be 0
		And log output should include following entries:
			| Starting DMS Poller version |
			| DMS Poller ready |
			| running <cycles> cycles |
		And log output should include "<log line>" <times>

		Examples:
			| cycles	| log line						| times	|
			| 0			| running probe: system/sysstat | 0		|
			| 1			| running probe: system/sysstat | 1		|
			| 3			| running probe: system/sysstat | 3		|
			| 3			| running probe: system/memory	| 1		|

