class CollectorThread < Thread
	def initialize(collector_bind_address)
		log.info "Binding collector socket at: #{collector_bind_address}"

		super do
			abort_on_exception = true

			ZeroMQ.new do |zmq|
				zmq.pull_bind(collector_bind_address) do |pull|
					loop do
						message = pull.recv
						if message.class != RawDatum
							log.warn "collected message of type: #{message.class.name}, expected RawDatum"
							next
						end

						log.debug "collected #{message}"
					end
				end 
			end 
		end
	end
end

