require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

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

