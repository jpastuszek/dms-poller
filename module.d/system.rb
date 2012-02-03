probe(:sysstat) do
	collect 'CPU usage', 'total', 'idle', 3123
	collect 'system', 'process', 'blocked', 0
end.schedule_every 1.second

probe(:memory) do
	collect 'system', '', 'total', 8182644
	collect 'system', '', 'free', 5577396
	collect 'system', '', 'buffers', 254404
end.schedule_every 4.seconds

