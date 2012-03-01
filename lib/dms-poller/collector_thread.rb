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

require 'dms-poller/processing_thread'

class CollectorThread < ProcessingThread
	def initialize(shutdown_queue, collector_bind_address, data_processor_address, queue_message_count, disk_queue_size, linger_time)
		log.info "Binding collector socket at: #{collector_bind_address}"
		log.info "Connecting collector with data porcessor at: #{data_processor_address}"

		super(shutdown_queue) do
			ZeroMQ.new do |zmq|
				begin
					zmq.pull_bind(collector_bind_address) do |pull|
						zmq.push_connect(data_processor_address, hwm: queue_message_count, swap: disk_queue_size, buffer: 0, linger: linger_time) do |push|
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

