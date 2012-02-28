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

require 'pathname'
require 'active_support/core_ext'

class PollerModule < ModuleBase
	class Probe
		attr_reader :name
		attr_reader :schedule

		def initialize(name, &block)
			@name = name
			@probe_code = block
			@schedule = 60.0
		end

		def run(location, &block)
			begin
				@location = location
				@collector = block
				instance_eval &@probe_code
			rescue => e
				log.error "Probe #{@name} raised error: #{e.class.name}: #{e.message}"
			ensure
				@location = nil
				@collector = nil
			end
		end

		def schedule_every(seconds)
			@schedule = seconds.to_f
			self
		end

		def to_s
			name
		end

		def inspect
			"Probe[#{name}]"
		end

		private

		def collect(path, component, value, options = {})
			@collector.call(RawDataPoint.new((options[:location] or @location), path, component, value))
		end
	end

	def initialize(module_name, &block)
		@probes = []
		dsl_method :probe do |probe_name, &block|
			Probe.new("#{module_name}/#{probe_name}", &block).tap{|probe| @probes << probe}
		end

		super

		if @probes.empty?
			log.warn "module '#{module_name}' defines no probes"
		else
			log.info { "loaded probes: #{@probes.map{|p| "#{p.to_s}"}.sort.join(', ')}" }
		end
	end

	attr_reader :probes
end

class PollerModules < ModuleLoader
	def initialize
		super(PollerModule)
	end
end

