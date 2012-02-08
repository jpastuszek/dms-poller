require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SchedulerThread do
	subject do
		m_system = PollerModule.new(:system) do
			probe(:sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				collect 'system', 'process', 'blocked', 0
			end.schedule_every 1.second

			probe(:memory) do
				collect 'system', '', 'total', 8182644
				collect 'system', '', 'free', 5577396
				collect 'system', '', 'buffers', 254404
			end.schedule_every 2.seconds
		end

		m_jmx = PollerModule.new(:jmx) do
			probe(:gc) do
				collect 'JMX', '1234/GC/PermGen', 'collections', 231
			end
		end

		#stderr_read do
	#		t = SchedulerThread.new({:system => m_system, :jmx => m_jmx}, 'ipc:///tmp/dms-poller-rspec-test')
		#end
	#	t
	end
end

