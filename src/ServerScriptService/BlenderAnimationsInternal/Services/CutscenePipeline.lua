--!strict
-- CutscenePipeline.lua
-- MCP-callable orchestration layer for AI-driven animation event authoring.
-- Operates directly on KeyframeSequence instances inside AnimSaves folders.
-- Does NOT touch the plugin's Fusion State — fully decoupled from plugin UI.

local AssetService = game:GetService("AssetService")

local CutscenePipeline = {}

-- default fps if no attribute is stored on the sequence
local DEFAULT_FPS = 30

------------------------------------------------------------
-- internal helpers
------------------------------------------------------------

-- Finds a KeyframeSequence by name inside the given rig model's AnimSaves folder.
-- rigModel: the rig Model in workspace. If nil, searches all rigs in workspace.
local function findSequence(seqName: string, rigModel: Model?): KeyframeSequence?
	local function searchAnimSaves(model: Instance): KeyframeSequence?
		local animSaves = model:FindFirstChild("AnimSaves")
		if not animSaves then return nil end
		for _, child in animSaves:GetChildren() do
			if child:IsA("KeyframeSequence") and child.Name == seqName then
				return child :: KeyframeSequence
			end
		end
		return nil
	end

	if rigModel then
		return searchAnimSaves(rigModel)
	end

	-- search all top-level workspace children for AnimSaves
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			local found = searchAnimSaves(child)
			if found then return found end
		end
	end
	return nil
end

-- Gets the source FPS stored on the sequence, or falls back to DEFAULT_FPS.
local function getFPS(seq: KeyframeSequence): number
	local fps = seq:GetAttribute("SourceFPS")
	if type(fps) == "number" and fps > 0 then
		return fps
	end
	return DEFAULT_FPS
end

-- Finds the Keyframe closest to a target time within epsilon, or creates one.
local function findOrCreateKeyframe(seq: KeyframeSequence, targetTime: number): Keyframe
	local epsilon = 0.001
	local closest: Keyframe? = nil
	local closestDist = math.huge

	for _, kf in seq:GetKeyframes() do
		local dist = math.abs((kf :: Keyframe).Time - targetTime)
		if dist < epsilon then
			return kf :: Keyframe
		end
		if dist < closestDist then
			closestDist = dist
			closest = kf :: Keyframe
		end
	end

	-- no keyframe close enough — create one
	local newKf = Instance.new("Keyframe")
	newKf.Time = targetTime
	newKf.Parent = seq
	return newKf
end

------------------------------------------------------------
-- public API
------------------------------------------------------------

-- Lists all KeyframeSequences in the active rig's AnimSaves.
-- rigModel: optional — if nil, searches all workspace models.
-- Returns: { { name: string, duration: number, priority: string, markerCount: number, fps: number } }
function CutscenePipeline:listAnimations(rigModel: Model?): { any }
	local results = {}

	local function scan(model: Instance)
		local animSaves = model:FindFirstChild("AnimSaves")
		if not animSaves then return end
		for _, child in animSaves:GetChildren() do
			if child:IsA("KeyframeSequence") then
				local seq = child :: KeyframeSequence
				local markerCount = 0
				for _, kf in seq:GetKeyframes() do
					markerCount += #(kf :: Keyframe):GetMarkers()
				end
				table.insert(results, {
					name = seq.Name,
					duration = seq:GetAttribute("Duration") or 0,
					priority = seq.Priority.Name,
					markerCount = markerCount,
					fps = getFPS(seq),
					rig = model.Name,
				})
			end
		end
	end

	if rigModel then
		scan(rigModel)
	else
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") then scan(child) end
		end
	end

	return results
end

-- Adds a KeyframeMarker at a specific FRAME number.
-- The frame is converted to seconds using the stored SourceFPS attribute (or 30fps default).
-- seqName:   name of the KeyframeSequence in AnimSaves
-- eventName: the marker name (what SceneDirector's GetMarkerReachedSignal listens for)
-- frame:     the Blender frame number
-- value:     optional string value to pass with the marker signal
-- rigModel:  optional — if nil, searches all workspace models
function CutscenePipeline:addEvent(seqName: string, eventName: string, frame: number, value: string?, rigModel: Model?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		error("KeyframeSequence not found: " .. seqName)
	end

	local fps = getFPS(seq)
	local targetTime = frame / fps

	local keyframe = findOrCreateKeyframe(seq, targetTime)

	-- check if a marker with this name already exists and remove it
	for _, marker in keyframe:GetMarkers() do
		if marker.Name == eventName then
			marker:Destroy()
		end
	end

	local marker = Instance.new("KeyframeMarker")
	marker.Name = eventName
	marker.Value = value or ""
	keyframe:AddMarker(marker)

	return {
		name = eventName,
		frame = frame,
		time = targetTime,
		fps = fps,
	}
end

-- Removes a named marker from the sequence (across all keyframes).
function CutscenePipeline:removeEvent(seqName: string, eventName: string, rigModel: Model?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		error("KeyframeSequence not found: " .. seqName)
	end

	local removed = 0
	for _, kf in seq:GetKeyframes() do
		for _, marker in (kf :: Keyframe):GetMarkers() do
			if marker.Name == eventName then
				marker:Destroy()
				removed += 1
			end
		end
	end

	return { removed = removed }
end

-- Lists all markers in a KeyframeSequence, showing frame numbers.
-- Returns: { { name: string, frame: number, time: number, value: string } }
function CutscenePipeline:listEvents(seqName: string, rigModel: Model?): { any }
	local seq = findSequence(seqName, rigModel)
	if not seq then
		error("KeyframeSequence not found: " .. seqName)
	end

	local fps = getFPS(seq)
	local events = {}

	for _, kf in seq:GetKeyframes() do
		local keyframe = kf :: Keyframe
		for _, marker in keyframe:GetMarkers() do
			table.insert(events, {
				name = marker.Name,
				frame = math.round(keyframe.Time * fps),
				time = keyframe.Time,
				value = marker.Value,
			})
		end
	end

	-- sort by frame
	table.sort(events, function(a, b) return a.frame < b.frame end)

	return events
end

-- Sets the animation priority on a KeyframeSequence.
-- priority: "Core" | "Idle" | "Movement" | "Action" | "Action2" | "Action3" | "Action4"
function CutscenePipeline:setPriority(seqName: string, priority: string, rigModel: Model?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		error("KeyframeSequence not found: " .. seqName)
	end

	local enumVal = (Enum.AnimationPriority :: any)[priority]
	if not enumVal then
		error("Invalid priority: " .. priority .. ". Use Core/Idle/Movement/Action/Action2/Action3/Action4")
	end

	seq.Priority = enumVal
	return { name = seqName, priority = priority }
end

-- Stores the source FPS as an attribute for frame-to-time conversion.
function CutscenePipeline:setFPS(seqName: string, fps: number, rigModel: Model?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		error("KeyframeSequence not found: " .. seqName)
	end

	seq:SetAttribute("SourceFPS", fps)
	return { name = seqName, fps = fps }
end

-- Uploads a KeyframeSequence via CreateAssetAsync.
-- Returns the assetId on success, or nil + error message on failure.
-- Also stores the returned assetId as an attribute on the KFS for future re-uploads.
function CutscenePipeline:upload(seqName: string, rigModel: Model?): (number?, string?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		return nil, "KeyframeSequence not found: " .. seqName
	end

	-- CreateAssetAsync(instance, assetType, config) — instance comes FIRST
	-- returns (Enum.CreateAssetResult, assetId) as a multi-return
	-- pcall captures as (ok, createResult, assetId)
	local ok, createResult, assetId = pcall(function()
		return AssetService:CreateAssetAsync(
			seq,
			Enum.AssetType.Animation,
			{ Name = seqName, Description = "Uploaded via CutscenePipeline" }
		)
	end)

	if ok then
		if createResult == Enum.CreateAssetResult.Success and assetId then
			seq:SetAttribute("UploadedAssetId", assetId)
			return assetId, nil
		else
			return nil, "CreateAssetAsync returned: " .. tostring(createResult) .. " (assetId: " .. tostring(assetId) .. ")"
		end
	else
		return nil, "CreateAssetAsync failed: " .. tostring(createResult)
	end
end

-- Re-uploads an existing animation (new version).
-- If no existingAssetId is provided, looks for the UploadedAssetId attribute.
function CutscenePipeline:reupload(seqName: string, existingAssetId: number?, rigModel: Model?): (number?, string?)
	local seq = findSequence(seqName, rigModel)
	if not seq then
		return nil, "KeyframeSequence not found: " .. seqName
	end

	local assetId = existingAssetId or seq:GetAttribute("UploadedAssetId")
	if not assetId then
		return nil, "No existing assetId found. Upload first, or pass an assetId."
	end

	-- CreateAssetVersionAsync(instance, assetType, assetId, config)
	local ok, errMsg = pcall(function()
		return AssetService:CreateAssetVersionAsync(
			seq,
			Enum.AssetType.Animation,
			assetId,
			{ Name = seqName, Description = "Re-uploaded via CutscenePipeline" }
		)
	end)

	if ok then
		seq:SetAttribute("UploadedAssetId", assetId)
		return assetId, nil
	else
		return nil, "CreateAssetVersionAsync failed: " .. tostring(errMsg)
	end
end

return CutscenePipeline
