require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'dms-poller/process_pool'

describe ProcessPool do
	describe ProcessPool::Process do
		it "should provide status, pid, time-out and exitstatus" do
			process = nil

			ProcessPool.new do |process_pool|
				process = process_pool.process(10) do
					sleep 0.1
					exit!(42)
				end

				process.pid.should > 0
				process.should be_running
				process.time_out.should == 10
			end

			process.should_not be_running
			process.exitstatus.should == 42
		end
	end

	it "should exit with status 201 when specified time-out time has passed" do
		process = nil

		ProcessPool.new do |process_pool|
			process = process_pool.process(0.05) do
				sleep 100
			end

			process.pid.should > 0
			process.running?.should == true
		end

		process.running?.should == false
		process.exitstatus.should == 201
	end

	it "should call on_timeout block with time-out value when time-out time has passed" do
		process = nil

		Capture.stdout do
			ProcessPool.new do |process_pool|
				process = process_pool.process(0.05) do |process|
					process.on_timeout do |timeout|
						puts "time-out after #{timeout} seconds!"
					end
					sleep 100
				end
			end

			process.exitstatus.should == 201
		end.should include('time-out after 0.05 seconds!')
	end

	it "should limit maximum number of running processes" do
			ProcessPool.new(2) do |process_pool|
				process_pool.process do
					sleep 0.1
				end

				process_pool.process do
					sleep 0.1
				end

				expect {
					process_pool.process do
						sleep 0.1
					end
				}.to raise_error(ProcessPool::ProcessLimitReachedError)

				begin
					process_pool.process do
						sleep 0.1
					end
				rescue ProcessPool::ProcessLimitReachedError => error
					error.process_limit.should == 2
					error.running_pids.should have(2).pids
				end
			end
	end

	it "should provide list of running pids" do
		ProcessPool.new do |process_pool|
			2.times do
				process_pool.process do
					sleep 0.1
				end
			end

			process_pool.running_pids.should have(2).pids
			process_pool.running_pids.first.should > 0
			process_pool.running_pids.last.should > 0
		end
	end

	it "should wait for processes to exit" do
		processes = []

		ProcessPool.new do |process_pool|
			2.times do
				processes << process_pool.process do
					sleep 0.1
				end
			end

			process_pool.running_pids.should have(2).pids
			processes.each do |process|
				process.should be_running
			end

		end.running_pids.should be_empty
		processes.each do |process|
			process.should_not be_running
		end
	end

	it "should provide configured process limit" do
		ProcessPool.new(2) do |process_pool|
			process_pool.process_limit.should == 2
		end
	end
end

