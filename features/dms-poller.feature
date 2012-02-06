Feature: Poller startup and testing features
  In order to being able to test dms-poller executatble
  It has to support running specified number of cycles
  and with time scaling

  Scenario: Poller startup with 0 cycles
	Given dms-poller program
    When it is started in debug with arguments -c 0
	Then exit status will be 0
	And log output should include following entries:
		| Starting DMS Poller version |
		| DMS Poller ready |
		| running 0 cycles |
	But log output should not include following entries:
		| running probe |

  Scenario: Poller startup with 1 cycle and time scale
	Given dms-poller program
    When it is started in debug with arguments -c 1 -t 0.01
	Then exit status will be 0
	And log output should include following entries:
		| Starting DMS Poller version |
		| DMS Poller ready |
		| running 1 cycles |
	And log output should include "running probe: system/sysstat" once


  Scenario: Poller startup with 1 cycle and time scale
	Given dms-poller program
    When it is started in debug with arguments -c 3 -t 0.01
	Then exit status will be 0
	And log output should include following entries:
		| Starting DMS Poller version |
		| DMS Poller ready |
		| running 3 cycles |
	And log output should include "running probe: system/sysstat" three times

