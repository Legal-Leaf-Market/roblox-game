--!strict
-- Every remote in one place. The server creates them; clients wait for them.
--   Shoot   client -> server  (angle: number, power: number)
--   Place   client -> server  (x: number, y: number)  ball in hand
--   Play    server -> clients (frames, ids)            animate a shot
--   State   server -> clients (state table)            whose turn, groups, message

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}
local NAMES = { "Shoot", "Place", "Play", "State" }

function Net.folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			for _, n in NAMES do
				local r = Instance.new("RemoteEvent")
				r.Name = n
				r.Parent = nf
			end
			nf.Parent = ReplicatedStorage
			return nf
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.get(name: string): RemoteEvent
	return Net.folder():WaitForChild(name) :: RemoteEvent
end

return Net
