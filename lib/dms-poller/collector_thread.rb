require 'dms-poller/processing_thread'

class CollectorThread < ProcessingThread
	def initialize(shutdown_queue, collector_bind_address, data_processor_address, location, queue_message_count, disk_queue_size)
		log.info "Binding collector socket at: #{collector_bind_address}"
		log.info "Connecting collector with data porcessor at: #{data_processor_address}"

		super(shutdown_queue) do
			ZeroMQ.new do |zmq|
				begin
					zmq.pull_bind(collector_bind_address) do |pull|
						zmq.push_connect(data_processor_address, queue_message_count, disk_queue_size, 100) do |push|
							loop do
								message = pull.recv
								if message.class != RawDatum
									log.warn "collected message of type: #{message.class.name}, expected RawDatum"
									next
								end

								raw_data_point = message.to_raw_data_point(location)

								log.debug "sending #{raw_data_point}"
								push.send raw_data_point
							end
						end
					end 
				ensure
					log.info "waiting for messages to be sent..."
				end
			end 
		end
	end
end

