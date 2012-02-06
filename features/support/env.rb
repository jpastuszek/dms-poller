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

def run(program, args, debug = false)
	args = args.split(' ').unshift('-d').join(' ') if debug

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

class String
	def times
		case self
			when 'once' then 1
			when 'three times' then 3
		else
			raise "unknown word '#{self}'"
		end
	end
end

