require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'dms-poller'

require 'rspec/expectations'
require 'capture-output'
require 'tmpdir'

def run(program, args)
	out = []
	out << Capture.stdout do	
		out << Capture.stderr do	
			pid = Process.spawn("bundle exec bin/#{program} #{args}")
			Process.waitpid(pid)
			out << $?
		end
	end
	
	out.reverse
end

def temp_dir(name)
	dir = Pathname.new(Dir.mktmpdir(name))

	at_exit do
		dir.rmtree
	end

	dir
end


