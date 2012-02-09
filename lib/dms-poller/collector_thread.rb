class CollectorThread < Thread
	def initialize(collector_bind_address, data_processor_address, location)
		log.info "Binding collector socket at: #{collector_bind_address}"
		log.info "Connecting collector with data porcessor at: #{data_processor_address}"

		super do
			abort_on_exception = true

			ZeroMQ.new do |zmq|
				zmq.pull_bind(collector_bind_address) do |pull|
					zmq.push_connect(data_processor_address) do |push|
						loop do
							message = pull.recv
							if message.class != RawDatum
								log.warn "collected message of type: #{message.class.name}, expected RawDatum"
								next
							end

							raw_data_point = message.to_raw_data_point(location, Time.now.utc.to_i)

							log.debug "sending #{raw_data_point}"
							push.send raw_data_point
						end
					end
				end 
			end 
		end
	end
end

