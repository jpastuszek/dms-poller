require 'dms-poller/processing_thread'

class CollectorThread < ProcessingThread
	def initialize(shutdown_queue, collector_bind_address, data_processor_address, queue_message_count, disk_queue_size, linger_time)
		log.info "Binding collector socket at: #{collector_bind_address}"
		log.info "Connecting collector with data porcessor at: #{data_processor_address}"

		super(shutdown_queue) do
			ZeroMQ.new do |zmq|
				begin
					zmq.pull_bind(collector_bind_address) do |pull|
						zmq.push_connect(data_processor_address, queue_message_count, disk_queue_size, 0, linger_time) do |push|
							loop do
								message = pull.recv
								if message.class != RawDataPoint
									log.warn "collected message of type: #{message.class.name}, expected RawDataPoint"
									next
								end

								#log.debug "sending #{message}"
								push.send message
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

