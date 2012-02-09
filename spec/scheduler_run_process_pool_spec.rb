require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SchedulerRunProcessPool do
	before :all do
		m_system = PollerModule.new(:system) do
			probe(:sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				collect 'system', 'process', 'blocked', 0
			end.schedule_every 10.second

			probe(:memory) do
				collect 'system', '', 'total', 8182644
				collect 'system', '', 'free', 5577396
				collect 'system', '', 'buffers', 254404
			end.schedule_every 30.seconds
		end

		m_jmx = PollerModule.new(:jmx) do
			probe(:gc) do
				collect 'JMX', '1234/GC/PermGen', 'collections', 231
			end.schedule_every 60.seconds
		end

		@probes = []
		m_system.merge(m_jmx).each_value do |probe|
			@probes << probe
		end

		@addr = 'ipc:///tmp/dms-poller-test'
	end

	it "should produce RawDatum objects on ZeroMQ endpoint" do
		ZeroMQ.new do |zmq|
			zmq.pull_bind(@addr) do |pull|
				SchedulerRunProcessPool.new(10, 2) do |pool|
					pool.fork_process(@probes, @addr, 0)
				end

				raw_data = []
				5.times do
					raw_data << pull.recv
				end

				raw_data.should have(5).raw_datum
				raw_data.first.should be_a RawDatum
				raw_data.first.type.should == 'CPU usage'
				raw_data.first.group.should == 'total'
				raw_data.first.component.should == 'idle'
				raw_data.first.value.should == 3123
			end
		end
	end
end

