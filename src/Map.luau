--!strict
-- ^ yo strict is killing me son

--// Imports
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local BufferReader = require("./BufferReader")
local BufferWriter = require("./BufferWriter")
local ZipWriter = require("./ZipWriter")
local Types = require("./types")

--// Types
export type MapMetadata = Types.MapMetadata
export type Note = Types.Note
export type VfxObject = Types.VfxObject

export type Map = typeof(setmetatable(
	{} :: {
		metadata: MapMetadata,
		soundId: string,
		notes: { Note },
		vfxObjects: { VfxObject },
	},
	{} :: MapMeta
))

type MapMeta = {
	__index: (Map, string) -> any,
	new: (metadata: MapMetadata?) -> Map,
	load: (path: string) -> Map,
	addNote: (self: Map, x: number, y: number, ms: number) -> (),
	addVfx: (self: Map, typeId: number, timestamp: number, params: { any }) -> (),
	setAudio: (self: Map, src: string | buffer) -> (),
	save: (self: Map, path: string) -> (),
	_savePHXM: (self: Map, path: string) -> (),
	_saveSSPM: (self: Map, path: string) -> (),
}

--// Constants
local DEFAULT_METADATA: MapMetadata = {
	Artist = "Unknown",
	AudioExt = "mp3",
	Difficulty = 0,
	DifficultyName = "Normal",
	HasAudio = false,
	HasCover = false,
	HasVideo = false,
	ID = "unknown_0",
	Mappers = { "Unknown" },
	Rating = 0,
	Title = "New Map",
}

--// Private Methods
local function parseObj(reader: any, typeId: number): { any }
	if typeId == 2 then -- brightness
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 3 then -- contrast
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 4 then -- saturation
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 5 then -- blur
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 6 then -- fov
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 7 then -- tint
		return {
			reader:readUInt32(),
			reader:readByte(),
			reader:readByte(),
			reader:readByte(),
			reader:readByte(),
			reader:readByte(),
		}
	elseif typeId == 8 then -- position
		return {
			reader:readUInt32(),
			reader:readByte(),
			reader:readByte(),
			reader:readSingle(),
			reader:readSingle(),
			reader:readSingle(),
		}
	elseif typeId == 9 then -- rotation
		return { reader:readUInt32(), reader:readByte(), reader:readByte(), reader:readSingle() }
	elseif typeId == 10 then -- ar factor
		return { reader:readSingle() }
	elseif typeId == 11 then -- text
		return { reader:readUInt32(), reader:readString(), reader:readByte() }
	end
	return {}
end

local function serializeObj(writer: any, typeId: number, params: { any })
	if typeId >= 2 and typeId <= 6 then -- brightness, contrast, saturation, blur, fov
		writer:writeUInt32(params[1])
		writer:writeByte(params[2])
		writer:writeByte(params[3])
		writer:writeSingle(params[4])
	elseif typeId == 7 then -- tint
		for i = 1, 6 do
			writer:writeByte(params[i])
		end
	elseif typeId == 8 then -- position
		writer:writeUInt32(params[1])
		writer:writeByte(params[2])
		writer:writeByte(params[3])
		writer:writeSingle(params[4])
		writer:writeSingle(params[5])
		writer:writeSingle(params[6])
	elseif typeId == 9 then -- rotation
		writer:writeUInt32(params[1])
		writer:writeByte(params[2])
		writer:writeByte(params[3])
		writer:writeSingle(params[4])
	elseif typeId == 10 then -- ar factor
		writer:writeSingle(params[1])
	elseif typeId == 11 then -- text
		writer:writeUInt32(params[1])
		writer:writeString(params[2])
		writer:writeByte(params[3])
	end
end

--// Constructor
local MapClass = {}

function MapClass.new(metadata: MapMetadata?): Map
	local meta = metadata or DEFAULT_METADATA
	local self = {
		metadata = meta,
		soundId = meta.ID,
		notes = {},
		vfxObjects = {},
		_audioBuffer = nil :: buffer?,
	}
	setmetatable(self, { __index = MapClass })
	return self :: any
end

function MapClass.load(path: string): Map
	local metadataStr = fs.readFile(path .. "/metadata.json")
	local metadata = serde.decode("json", metadataStr) :: MapMetadata

	local objBuffer = fs.readFile(path .. "/objects.phxmo")
	local reader = BufferReader.new(buffer.fromstring(objBuffer))

	local typesCount = reader:readInt32()
	local noteCount = reader:readInt32()

	local notes: { Note } = table.create(noteCount)

	for i = 1, noteCount do
		local ms = reader:readUInt32()
		local quantum = reader:readBoolean()

		local x: number
		local y: number

		if quantum then
			x = 1 - reader:readSingle()
			y = reader:readSingle() + 1
		else
			x = 2 - reader:readByte()
			y = reader:readByte()
		end

		table.insert(notes, { x = x, y = y, ms = ms })
	end

	local vfxObjects: { VfxObject } = {}

	for i = 2, typesCount + 1 do
		local count = reader:readInt32()
		for _ = 1, count do
			local timestamp = reader:readUInt32()
			local params = parseObj(reader, i)

			table.insert(vfxObjects, {
				typeId = i,
				timestamp = timestamp,
				params = params,
			})
		end
	end

	local self = {
		metadata = metadata,
		soundId = metadata.ID,
		notes = notes,
		vfxObjects = vfxObjects,
	}
	setmetatable(self, { __index = MapClass })
	return self :: any
end

--// API
function MapClass:addNote(x: number, y: number, ms: number)
	table.insert(self.notes, { x = x, y = y, ms = ms })
end

function MapClass:addVfx(typeId: number, timestamp: number, params: { any })
	table.insert(self.vfxObjects, {
		typeId = typeId,
		timestamp = timestamp,
		params = params,
	})
end

function MapClass:setAudio(src: string | buffer)
	if type(src) == "string" then
		self._audioBuffer = buffer.fromstring(fs.readFile(src))
	else
		self._audioBuffer = src
	end
	self.metadata.HasAudio = true
end

function MapClass:_savePHXM(path: string)
	local metadataStr = serde.encode("json", self.metadata :: any, true)

	local writer = BufferWriter.new()

	local maxTypeId = 0
	local vfxByType: { [number]: { VfxObject } } = {}

	for _, vfx in ipairs(self.vfxObjects) do
		if vfx.typeId > maxTypeId then
			maxTypeId = vfx.typeId
		end
		if not vfxByType[vfx.typeId] then
			vfxByType[vfx.typeId] = {}
		end
		table.insert(vfxByType[vfx.typeId], vfx)
	end

	local typesCount = maxTypeId > 1 and (maxTypeId - 1) or 0
	writer:writeInt32(typesCount)
	writer:writeInt32(#self.notes)

	for _, note in ipairs(self.notes) do
		writer:writeUInt32(note.ms)

		local isQuantum = (note.x % 1 ~= 0) or (note.y % 1 ~= 0) or note.x < 0 or note.x > 2 or note.y < 0 or note.y > 2
		writer:writeBoolean(isQuantum)

		if isQuantum then
			writer:writeSingle(1 - note.x)
			writer:writeSingle(note.y - 1)
		else
			writer:writeByte(2 - math.round(note.x))
			writer:writeByte(math.round(note.y))
		end
	end

	for i = 2, typesCount + 1 do
		local objects = vfxByType[i] or {}
		writer:writeInt32(#objects)

		for _, vfx in ipairs(objects) do
			writer:writeUInt32(vfx.timestamp)
			serializeObj(writer, i, vfx.params)
		end
	end

	local finalBuffer = writer:getBuffer()

	if path:sub(-5):lower() == ".phxm" then
		local zip = ZipWriter.new()
		zip:addFile("metadata.json", buffer.fromstring(metadataStr))
		zip:addFile("objects.phxmo", finalBuffer)

		if self._audioBuffer then
			local ext = self.metadata.AudioExt or "mp3"
			zip:addFile("audio." .. ext, self._audioBuffer)
		end

		fs.writeFile(path, zip:getBuffer())
	else
		if not fs.isDir(path) then
			fs.writeDir(path)
		end
		fs.writeFile(path .. "/metadata.json", metadataStr)
		fs.writeFile(path .. "/objects.phxmo", buffer.tostring(finalBuffer))
	end
end

function MapClass:_saveSSPM(path: string)
	local writer = BufferWriter.new()

	-- SS+m blehhhhh
	writer:writeByte(0x53)
	writer:writeByte(0x53)
	writer:writeByte(0x2B)
	writer:writeByte(0x6D)

	-- 2
	writer:writeUInt16(0x0002)
	-- 4 bytes
	writer:writeUInt32(0x00000000)

	-- 20 byte
	for i = 1, 20 do
		writer:writeByte(0)
	end

	local lastMs = 0
	if #self.notes > 0 then
		lastMs = self.notes[#self.notes].ms
	end

	writer:writeUInt32(lastMs)
	writer:writeUInt32(#self.notes)
	writer:writeUInt32(#self.notes + 1)

	writer:writeByte(self.metadata.Difficulty or 0)
	writer:writeUInt16(self.metadata.Rating or 0)
	writer:writeBoolean(self._audioBuffer ~= nil)
	writer:writeBoolean(false)
	writer:writeBoolean(false)

	local pointerOffset = writer._cursor
	for i = 1, 80 do
		writer:writeByte(0)
	end

	writer:writeString(self.metadata.ID)
	writer:writeString(self.metadata.Title)
	writer:writeString(self.metadata.Title) -- mapName again

	writer:writeUInt16(self.metadata.Mappers and #self.metadata.Mappers or 0)
	if self.metadata.Mappers then
		for _, mapper in ipairs(self.metadata.Mappers) do
			writer:writeString(mapper)
		end
	end

	local customDataOffset = 0
	local customDataLength = 0
	if self.metadata.DifficultyName and self.metadata.DifficultyName ~= "" then
		customDataOffset = writer._cursor
		writer:writeUInt16(1)
		writer:writeString("difficulty_name")
		writer:writeByte(0x09)
		writer:writeString(self.metadata.DifficultyName)
		customDataLength = writer._cursor - customDataOffset
	else
		writer:writeUInt16(0)
	end

	local audioOffset = writer._cursor
	local audioLength = 0

	if self._audioBuffer then
		local audioBufStr = buffer.tostring(self._audioBuffer)
		writer:writeBytes(self._audioBuffer)
		audioLength = #audioBufStr
	end

	local coverOffset = writer._cursor
	local coverLength = 0

	local markerDefinitionsOffset = writer._cursor
	writer:writeByte(0x02)
	writer:writeString("ssp_note")
	writer:writeByte(0x01)
	writer:writeByte(0x07)
	writer:writeByte(0x00)

	writer:writeString("ssp_bpm")
	writer:writeByte(0x01)
	writer:writeByte(0x01)
	writer:writeByte(0x00)
	local markerDefinitionsLength = writer._cursor - markerDefinitionsOffset

	local markerOffset = writer._cursor
	for _, note in ipairs(self.notes) do
		writer:writeUInt32(note.ms)
		writer:writeByte(0x00) --ssp_note

		local isQuantum = (note.x % 1 ~= 0) or (note.y % 1 ~= 0) or note.x < 0 or note.x > 2 or note.y < 0 or note.y > 2
		writer:writeBoolean(isQuantum)

		if isQuantum then
			writer:writeSingle(2 - note.x)
			writer:writeSingle(2 - note.y)
		else
			writer:writeByte(2 - math.round(note.x))
			writer:writeByte(2 - math.round(note.y))
		end
	end

	writer:writeUInt32(0)
	writer:writeByte(0x01)
	writer:writeByte(0x01)
	local markerLength = writer._cursor - markerOffset

	local finalCursor = writer._cursor
	writer._cursor = pointerOffset

	writer:writeUInt64(customDataOffset)
	writer:writeUInt64(customDataLength)
	writer:writeUInt64(audioOffset)
	writer:writeUInt64(audioLength)
	writer:writeUInt64(coverOffset)
	writer:writeUInt64(coverLength)
	writer:writeUInt64(markerDefinitionsOffset)
	writer:writeUInt64(markerDefinitionsLength)
	writer:writeUInt64(markerOffset)
	writer:writeUInt64(markerLength)

	writer._cursor = finalCursor
	fs.writeFile(path, buffer.tostring(writer:getBuffer()))
end

function MapClass:save(path: string)
	if path:sub(-5):lower() == ".sspm" then
		self:_saveSSPM(path)
	else
		self:_savePHXM(path)
	end
end

return MapClass
