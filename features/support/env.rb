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
require 'timeout'
require 'facter'

def run(program, args = '')
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

def spawn(program, args = '')
	r, w = IO.pipe
	pid = Process.spawn("bundle exec bin/#{program} #{args}", :out => w)
	w.close

	thread = Thread.new do
		r.read
	end

	return pid, thread
end

def temp_dir(name)
	dir = Pathname.new(Dir.mktmpdir(name))

	at_exit do
		dir.rmtree
	end

	dir
end


