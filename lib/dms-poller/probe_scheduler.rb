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

require 'periodic-scheduler'

class ProbeScheduler
	def initialize(quantum, time_scale)
		log.info "using scheduler quantum of #{quantum} seconds"
		log.warn "using time scale of #{time_scale}" if time_scale != 1.0
		@all_probes = []
		@time_scale = time_scale
		@scheduler = PeriodicScheduler.new(quantum)
	end

	def schedule_probes(probes)
		probes.each do |probe|
			begin
				schedule = probe.schedule * @time_scale 
				log.info "scheduling probe #{probe} to run every #{schedule} seconds"
				@scheduler.every(schedule) do
					probe
				end

				@all_probes << probe
			rescue => error
				log.error "failed to schedule probe: #{probe}", error
			end
		end
	end

	def run!(runs, startup_run = false)
		log.info "running #{runs} runs" if runs
		cycle(runs) do |run_no|
			probes = if startup_run and run_no == 1
				@all_probes	
			else
				@scheduler.run do |error|
					log.error "scheduler runtime error", error
				end
			end

			yield probes, run_no
		end
	end

	private

	def cycle(runs = nil)
		run_no = 1
		until runs and run_no > runs
			yield run_no
			run_no += 1
		end
	end
end

