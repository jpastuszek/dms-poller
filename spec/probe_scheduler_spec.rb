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

describe ProbeScheduler do
	subject do
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

		# be quiet
		Logging.logger.root.level = :fatal

		probe_scheduler = ProbeScheduler.new(0.01, 0.01)
		probe_scheduler.schedule_modules({:system => m_system, :jmx => m_jmx})
		probe_scheduler
	end

	it "should not run any probes if asked to run 0 runs" do
		run_probes = []
		subject.run!(0) do |probes, run_no|
			run_probes << probes
		end

		run_probes.should be_empty
	end
		
	it "should run specified number of runs and yield probes to run and run number" do
		run_probes = []
		runs = []
		subject.run!(3) do |probes, run_no|
			run_probes << probes
			runs << run_no
		end

		run_probes.should have(3).probe_sets

		# 10th second
		run_probes[0].should have(1).probe
		run_probes[0].first.module_name.should == :system
		run_probes[0].first.probe_name.should == :sysstat

		# 20th second
		run_probes[1].should have(1).probes
		run_probes[1].first.module_name.should == :system
		run_probes[1].first.probe_name.should == :sysstat

		# 30th second
		run_probes[2].should have(2).probes
		run_probes[2][0].module_name.should == :system
		run_probes[2][0].probe_name.should == :memory
		run_probes[2][1].module_name.should == :system
		run_probes[2][1].probe_name.should == :sysstat

		runs.should == [1, 2, 3]
	end

	it "should support running all probes at first run and than continue scheduling as usual" do
		run_probes = []
		runs = []
		subject.run!(4, true) do |probes, run_no|
			run_probes << probes
			runs << run_no
		end

		run_probes.should have(4).probe_sets

		# first run we get all the probes
		run_probes[0].should have(3).probes
		run_probes[0][0].module_name.should == :system
		run_probes[0][0].probe_name.should == :sysstat
		run_probes[0][1].module_name.should == :system
		run_probes[0][1].probe_name.should == :memory
		run_probes[0][2].module_name.should == :jmx
		run_probes[0][2].probe_name.should == :gc

		# two single porbe runs for 10 and 20th second
		run_probes[1].should have(1).probe
		run_probes[1].first.module_name.should == :system
		run_probes[1].first.probe_name.should == :sysstat

		run_probes[2].should have(1).probe
		run_probes[2].first.module_name.should == :system
		run_probes[2].first.probe_name.should == :sysstat

		# 30th second has the systat and memory probe run
		run_probes[3].should have(2).probes
		run_probes[3][0].module_name.should == :system
		run_probes[3][0].probe_name.should == :memory
		run_probes[3][1].module_name.should == :system
		run_probes[3][1].probe_name.should == :sysstat

		runs.should == [1, 2, 3, 4]
	end
end

