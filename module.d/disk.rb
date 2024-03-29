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

probe('usage') do
	begin
		# On Mac: 
		# Filesystem                        1024-blocks      Used Available Capacity  iused   ifree %iused  Mounted on
		`df -k -l`.split("\n")[1..-1].map{|v| v.split(/\s+/)}.each do |volume|
			vol_name = volume[8]
			vol_name = 'ROOT' if vol_name == '/'

			#collect "disk/usage/#{vol_name}", 'total', volume[1].to_i * 1024
			collect "disk/usage/#{vol_name}", 'used', volume[2].to_i * 1024
			collect "disk/usage/#{vol_name}", 'free', volume[3].to_i * 1024
		end
	rescue Errno::ENOENT
		# df tool not available
	end
end

