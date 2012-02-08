$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'dms-poller'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

require 'capture-output'

def stderr_read
	r, w = IO.pipe
	old_stdout = STDERR.clone
	STDERR.reopen(w)
	data = ''
	t = Thread.new do
		data << r.read
	end
	begin
		yield
	ensure
		w.close
		STDERR.reopen(old_stdout)
	end
	t.join
	data
end

