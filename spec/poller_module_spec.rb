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

describe PollerModule do
	describe PollerModule::Probe do
		subject do
			PollerModule::Probe.new('system/sysstat') do
				collect 'CPU usage/total', 'idle', 3123
				collect 'CPU usage/total', 'usage', 12
				collect 'CPU usage/total', 'nice', 342
				collect 'CPU usage/CPU/1', 'idle', 3123
				collect 'CPU usage/CPU/1', 'usage', 12
				collect 'CPU usage/CPU/2', 'nice', 342
				collect 'system/process', 'context switches', 321231
				collect 'system/process', 'context switches', 321231
				collect 'system/process', 'running', 9
				collect 'system/process', 'blocked', 0, location: 'router01'
			end
		end

		it "has a module and probe name" do
			subject.name.should == 'system/sysstat'
		end

		it "provides RawDataPoint objects" do
			data = []
			subject.run('magi') do |raw_data_point|
				data << raw_data_point
			end

			data.should have(10).items

			data.first.should be_a RawDataPoint
			data.first.location.should == 'magi'
			data.first.path.should == 'CPU usage/total'
			data.first.component.should == 'idle'
			data.first.value.should == 3123

			data.last.location.should == 'router01'
		end

		it "logs collector exceptions" do
			p = PollerModule::Probe.new('system/sysstat') do
				collect 'CPU usage/total', 'idle', 3123
				raise "test error"
				collect 'system/process', 'blocked', 0
			end

			Capture.stderr do
				data = []
				p.run('magi') do |raw_data_point|
					data << raw_data_point
				end
				data.should have(1).element
			end.should include("probe system/sysstat raised error: RuntimeError: test error")
		end

		it "schedule default to 60 seconds" do
			subject.schedule.should == 60
		end

		it "can be scheduled to run every given number of seconds or minutes" do
			subject.schedule_every 10.5
			subject.schedule.should == 10.5

			subject.schedule_every 10.seconds
			subject.schedule.should == 10

			subject.schedule_every 10.minutes
			subject.schedule.should == 600
		end
	end

	subject do
		pm = nil
		Capture.stderr do
			pm = PollerModule.new('system') do
				probe('sysstat') do
					collect 'CPU usage/total', 'idle', 3123
					collect 'system/process', 'blocked', 0
				end

				probe('memory') do
					collect 'system/memory', 'total', 8182644
					collect 'system/memory', 'free', 5577396
					collect 'system/memory', 'buffers', 254404
				end
			end
		end
		pm
	end

	it "has a name" do
		subject.name.should == 'system'
	end

	it "provides access to probes" do
		subject.probes.should have(2).probes
		subject.probes.shift.should be_a PollerModule::Probe
		subject.probes.shift.should be_a PollerModule::Probe
	end
	
	it "can be loaded from string" do
		Capture.stderr do
			m = PollerModule.load('system', <<'EOF')
				probe('sysstat') do
				collect 'CPU usage/total', 'idle', 3123
				collect 'system/process', 'blocked', 0
			end
EOF
			m.probes.shift.should be_a PollerModule::Probe
		end
	end
end

describe PollerModules do
	before :all do
		@modules_dir = Pathname.new(Dir.mktmpdir('poller_moduled.d'))

		(@modules_dir + 'system.rb').open('w') do |f|
			f.write <<'EOF'
probe('sysstat') do
	collect 'CPU usage/total', 'idle', 3123
	collect 'system/process', 'blocked', 0
end

probe('memory') do
	collect 'system/memory', 'total', 8182644
	collect 'system/memory', 'free', 5577396
	collect 'system/memory', 'buffers', 254404
end
EOF
		end

		(@modules_dir + 'empty.rb').open('w') do |f|
			f.write('')
		end

		(@modules_dir + 'jmx.rb').open('w') do |f|
			f.write <<'EOF'
probe('gc') do
	collect 'JMX/1234/GC/PermGen', 'collections', 231
end
EOF
		end
	end

	it "should load module from file and log that" do
		pms = PollerModules.new
		
		mod = nil
		out = Capture.stderr do
			mod = pms.load_file(@modules_dir + 'system.rb')
		end

		mod.should be_a PollerModule

		mod.probes.should have(2).probes
		mod.probes.shift.should be_a PollerModule::Probe
		mod.probes.shift.should be_a PollerModule::Probe

		out.should include("loading module 'system' from:")
		out.should include("loaded probes: system/memory, system/sysstat")
	end

	it "should log warning message if loaded file has no probe definitions" do
		pms = PollerModules.new
		
		mod = nil
		out = Capture.stderr do
			mod = pms.load_file(@modules_dir + 'empty.rb')
		end

		mod.should be_a PollerModule
		mod.probes.should have(0).probes

		out.should include("WARN")
		out.should include("module 'empty' defines no probes")
	end

	it "should load directory in alphabetical order and log that" do
		pms = PollerModules.new
		
		modules = nil
		out = Capture.stderr do
			modules = pms.load_directory(@modules_dir)
		end

		modules.should have(3).module

		modules.first.should be_a PollerModule
		modules.first.name.should == 'empty'
		modules.shift.probes.should have(0).probes

		modules.first.should be_a PollerModule
		modules.first.name.should == 'jmx'
		modules.shift.probes.first.name.should == 'jmx/gc'

		modules.first.should be_a PollerModule
		modules.first.name.should == 'system'
		modules.first.probes.shift.name.should == 'system/sysstat'
		modules.shift.probes.shift.name.should == 'system/memory'

		out.should include("WARN")
		out.should include("loading module 'empty' from:")
		out.should include("module 'empty' defines no probes")

		out.should include("loading module 'system' from:")
		out.should include("loaded probes: system/memory, system/sysstat")

		out.should include("loading module 'jmx' from:")
		out.should include("loaded probes: jmx/gc")
	end

	it "should log error if module cannot be loaded" do
		module_file = Tempfile.new('bad_module')
		module_file.write 'raise "test error"'
		module_file.close

		pms = PollerModules.new
		
		out = Capture.stderr do
			pms.load_file(module_file.path).should be_nil
		end

		out.should include("ERROR")
		out.should include("error while loading module 'bad_module")
		out.should include("test error")
	end

	after :all do
		@modules_dir.rmtree
	end
end


