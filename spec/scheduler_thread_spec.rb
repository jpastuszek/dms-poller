require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SchedulerThread do
	it "should log scheduling of probes" do
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

		out = stderr_read do
			t = SchedulerThread.new({:system => m_system, :jmx => m_jmx})
		end

		out.should include("scheduling probe system/sysstat to run every 1.0 seconds")
		out.should include("scheduling probe system/memory to run every 2.0 seconds")
		out.should include("scheduling probe jmx/gc to run every 60.0 seconds")
	end
end

