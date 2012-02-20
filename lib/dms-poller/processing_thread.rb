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
		return unless alive?
		raise(Interrupt)
		unless join(time_out)
			log.warn "forced termination after #{time_out} seconds"
			terminate
		end
	end
end

