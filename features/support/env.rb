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

def dms_poller(debug, args)
	pid = Process.spawn("be ../bin/dms-poller #{debug ? '-d' : ''} #{args}")
	p pid
end

