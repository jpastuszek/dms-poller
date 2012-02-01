require 'dms-core'

class PollerModule < Hash
	class Probe
		def initialize(&block)
			@collector = block
		end

		def run
			@data = []
			instance_eval &@collector
			@data
		end

		private

		def collect(type, group, component, value)
			@data << RawDatum.new(type, group, component, value)
		end
	end

	def initialize(&block)
		instance_eval &block
	end

	def self.load(string)
		self.new do
			eval string
		end
	end

	private

	def probe(name, &block)
		self[name.to_sym] = Probe.new(&block)
	end
end

