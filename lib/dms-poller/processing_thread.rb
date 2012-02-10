require 'thread'

class ProcessingThread < Thread
	def initialize(shutdown_queue)
		super do
			begin
					yield
			rescue Interrupt
				log.info "exiting"
			rescue => e
				log.fatal "got error: #{e}: #{e.message}"
			ensure
				shutdown_queue.push self.class.name
			end
		end
	end

	def shutdown(time_out)
		raise(Interrupt)
		unless join(time_out)
			log.warn "forced termination after #{time_out} seconds"
			terminate
		end
	end
end

