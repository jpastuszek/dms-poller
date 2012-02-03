require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'tmpdir'
require 'tempfile'

describe PollerModule do
	describe PollerModule::Probe do
		subject do
			PollerModule::Probe.new(:system, :sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				collect 'CPU usage', 'total', 'usage', 12
				collect 'CPU usage', 'total', 'nice', 342
				collect 'CPU usage', 'CPU 1', 'idle', 3123
				collect 'CPU usage', 'CPU 1', 'usage', 12
				collect 'CPU usage', 'CPU 2', 'nice', 342
				collect 'system', 'process', 'context switches', 321231
				collect 'system', 'process', 'context switches', 321231
				collect 'system', 'process', 'running', 9
				collect 'system', 'process', 'blocked', 0
			end
		end

		it "has a module and probe name" do
			subject.module_name.should == :system
			subject.probe_name.should == :sysstat
		end

		it "provides RawDatum objects" do
			data = subject.run

			data.should have(10).items

			data.first.should be_a RawDatum
			data.first.type.should == 'CPU usage'
			data.first.group.should == 'total'
			data.first.component.should == 'idle'
			data.first.value.should == 3123
		end

		it "logs collector exceptions" do
			p = PollerModule::Probe.new(:system, :sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				raise "test error"
				collect 'system', 'process', 'blocked', 0
			end

			stderr_read do
				data = p.run
				data.should have(1).element
			end.should include("Probe system/sysstat raised error: RuntimeError: test error")
		end
	end

	subject do
		PollerModule.new(:system) do
			probe(:sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				collect 'system', 'process', 'blocked', 0
			end

			probe(:memory) do
				collect 'system', '', 'total', 8182644
				collect 'system', '', 'free', 5577396
				collect 'system', '', 'buffers', 254404
			end
		end
	end

	it "has a name" do
		subject.module_name.should == :system
	end

	it "provides access to probes" do
		subject[:sysstat].should be_a PollerModule::Probe
		subject[:memory].should be_a PollerModule::Probe
	end
	
	it "can be loaded from string" do
		m = PollerModule.load(:system, <<'EOF')
			probe(:sysstat) do
				collect 'CPU usage', 'total', 'idle', 3123
				collect 'system', 'process', 'blocked', 0
			end
EOF
		m[:sysstat].should be_a PollerModule::Probe
	end
end

describe PollerModules do
	before :all do
		@modules_dir = Pathname.new(Dir.mktmpdir('poller_moduled.d'))

		(@modules_dir + 'system.rb').open('w') do |f|
			f.write <<'EOF'
probe(:sysstat) do
	collect 'CPU usage', 'total', 'idle', 3123
	collect 'system', 'process', 'blocked', 0
end

probe(:memory) do
	collect 'system', '', 'total', 8182644
	collect 'system', '', 'free', 5577396
	collect 'system', '', 'buffers', 254404
end
EOF
		end

		(@modules_dir + 'empty.rb').open('w') do |f|
			f.write('')
		end

		(@modules_dir + 'jmx.rb').open('w') do |f|
			f.write <<'EOF'
probe(:gc) do
	collect 'JMX', '1234/GC/PermGen', 'collections', 231
end
EOF
		end
	end

	it "should load module from file and log that" do
		pms = PollerModules.new
		
		out = stderr_read do
			pms.load_file(@modules_dir + 'system.rb')
		end

		pms.keys.should have(1).module
		pms[:system].should be_a PollerModule

		pms[:system].keys.should have(2).probes
		pms[:system][:sysstat].should be_a PollerModule::Probe
		pms[:system][:memory].should be_a PollerModule::Probe

		out.should include("loading module 'system' from:")
		out.should include("module 'system' probes: memory, sysstat")
	end

	it "should log warning message if loaded file has no probe definitions" do
		pms = PollerModules.new
		
		out = stderr_read do
			pms.load_file(@modules_dir + 'empty.rb')
		end

		pms.keys.should have(1).module
		pms[:empty].should be_a PollerModule

		out.should include("WARN")
		out.should include("module 'empty' defines not probes")
	end

	it "should load directory in alphabetical order and log that" do
		pms = PollerModules.new
		
		out = stderr_read do
			pms.load_directory(@modules_dir)
		end

		pms.keys.should have(3).module

		pms[:empty].should be_a PollerModule
		pms[:empty].module_name.should == :empty
		pms[:empty].keys.should have(0).probes

		pms[:jmx].should be_a PollerModule
		pms[:jmx].module_name.should == :jmx
		pms[:jmx].should include(:gc)

		pms[:system].should be_a PollerModule
		pms[:system].module_name.should == :system
		pms[:system].should include(:sysstat)
		pms[:system].should include(:memory)

		out.should include("WARN")
		out.should include("loading module 'empty' from:")
		out.should include("module 'empty' defines not probes")

		out.should include("loading module 'system' from:")
		out.should include("module 'system' probes: memory, sysstat")

		out.should include("loading module 'jmx' from:")
		out.should include("module 'jmx' probes: gc")
	end

	it "should log error if module cannot be loaded" do
		module_file = Tempfile.new('bad_module')
		module_file.write 'raise "test error"'
		module_file.close

		pms = PollerModules.new
		
		out = stderr_read do
			pms.load_file(module_file.path)
		end

		pms.should have(0).module

		out.should include("ERROR")
		out.should include("error while loading module 'bad_module")
		out.should include("': RuntimeError: (eval):1:in `load': test error")
	end

	after :all do
		@modules_dir.rmtree
	end
end

