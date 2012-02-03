probe(:sysstat) do
	collect 'CPU usage', 'total', 'idle', 3123
	collect 'system', 'process', 'blocked', 0
end.schedule_every 10.second

probe(:memory) do
	collect 'system', '', 'total', 8182644
	collect 'system', '', 'free', 5577396
	collect 'system', '', 'buffers', 254404
end.schedule_every 60.seconds

