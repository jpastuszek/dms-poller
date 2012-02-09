require 'pathname'
require 'active_support/core_ext'

class PollerModule < Hash
	class Probe
		attr_reader :module_name
		attr_reader :probe_name
		attr_reader :schedule

		def initialize(module_name, probe_name, &block)
			@module_name = module_name.to_sym
			@probe_name = probe_name.to_sym
			@collector = block
			@schedule = 60.0
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

		def schedule_every(seconds)
			@schedule = seconds.to_f
			self
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

class PollerModules < Hash
	def load_directory(module_dir)
		module_dir = Pathname.new(module_dir.to_s)
		
		module_dir.children.select{|f| f.extname == '.rb'}.sort.each do |module_file|
			load_file(module_file)
		end
	end

	def load_file(module_file)
		module_file = Pathname.new(module_file.to_s)

		module_name = module_file.basename(module_file.extname).to_s
		log.info "loading module '#{module_name}' from: #{module_file}"
		begin
			m = PollerModule.load(module_name, module_file.read)
			if m.keys.empty?
				log.warn "module '#{module_name}' defines not probes"
			else
				log.info { "module '#{module_name}' probes: #{m.keys.map{|p| "#{p.to_s}"}.sort.join(', ')}" }
			end
			self[module_name.to_sym] = m
		rescue => e
			log.error "error while loading module '#{module_name}': #{e.class.name}: #{e.message}"
		end
	end
end

