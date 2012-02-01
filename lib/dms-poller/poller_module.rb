require 'dms-core'

class PollerModule < Hash
	class Probe
		attr_reader :module_name
		attr_reader :probe_name

		def initialize(module_name, probe_name, &block)
			@module_name = module_name.to_sym
			@probe_name = probe_name.to_sym
			@collector = block
		end

		def run
			@data = []
			begin
				instance_eval &@collector
			rescue => e
				log.error "Probe #{@module_name}/#{@probe_name} raised error: #{e.class.name}: #{e.message}"
			end
			@data
		end

		private

		def collect(type, group, component, value)
			@data << RawDatum.new(type, group, component, value)
		end
	end

	attr_reader :module_name

	def initialize(module_name, &block)
		@module_name = module_name.to_sym
		instance_eval &block
	end

	def self.load(module_name, string)
		self.new(module_name) do
			eval string
		end
	end

	private

	def probe(probe_name, &block)
		self[probe_name.to_sym] = Probe.new(module_name, probe_name, &block)
	end
end

