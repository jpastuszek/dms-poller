# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SchedulerRunProcessPool do
	before :all do
		Capture.stderr do
			m_system = PollerModule.new('system') do
				probe('sysstat') do
					collect 'CPU usage/total', 'idle', 3123
					collect 'system/process', 'blocked', 0
				end.schedule_every 10.second

				probe('memory') do
					collect 'system/memory', 'total', 8182644
					collect 'system/memory', 'free', 5577396
					collect 'system/memory', 'buffers', 254404
				end.schedule_every 30.seconds
			end

			m_jmx = PollerModule.new('jmx') do
				probe('gc') do
					collect 'JMX/1234/GC/PermGen', 'collections', 231
				end.schedule_every 60.seconds
			end

			@probes = m_system.probes + m_jmx.probes
			@addr = 'ipc:///tmp/dms-poller-test'
		end
	end

	it "should produce RawDataPoint objects on ZeroMQ endpoint" do
		ZeroMQ.new do |zmq|
			zmq.pull_bind(@addr) do |pull|
				Capture.stderr do
					SchedulerRunProcessPool.new(10, 2) do |pool|
						pool.fork_process(@probes, 'magi', @addr, 0)
					end

					raw_data = []
					pull.on RawDataPoint do |message|
						raw_data << message
					end

					5.times do
						pull.receive!
					end

					raw_data.should have(5).raw_data_point
					raw_data.first.should be_a RawDataPoint
					raw_data.first.location.should == 'magi'
					raw_data.first.path.should == 'CPU usage/total'
					raw_data.first.component.should == 'idle'
					raw_data.first.value.should == 3123
				end
			end
		end
	end
end

