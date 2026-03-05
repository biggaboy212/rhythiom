--!strict

--// Imports
local BufferWriter = require("./BufferWriter")

--// Types
export type ZipWriter = typeof(setmetatable(
	{} :: {
		_writer: BufferWriter,
		_files: { ZipFileEntry },
		_offset: number,
	},
	{} :: ZipWriterMeta
))

export type ZipFileEntry = {
	name: string,
	data: buffer,
	crc32: number,
	uncompressedSize: number,
	compressedSize: number,
	headerOffset: number,
}

type ZipWriterMeta = {
	__index: ZipWriterMeta,
	new: () -> ZipWriter,
	addFile: (self: ZipWriter, name: string, data: buffer) -> (),
	getBuffer: (self: ZipWriter) -> buffer,
}

--// Private Methods
local crc32_table = {}
for i = 0, 255 do
	local c = i
	for j = 1, 8 do
		if bit32.band(c, 1) == 1 then
			c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
		else
			c = bit32.rshift(c, 1)
		end
	end
	crc32_table[i] = c
end

local function computeCRC32(data: buffer): number
	local c = 0xFFFFFFFF
	local len = buffer.len(data)
	for i = 0, len - 1 do
		local byte = buffer.readu8(data, i)
		local idx = bit32.bxor(bit32.band(c, 0xFF), byte)
		c = bit32.bxor(bit32.rshift(c, 8), crc32_table[idx])
	end
	return bit32.bxor(c, 0xFFFFFFFF)
end

--// Constructor
local ZipWriterClass = {} :: ZipWriterMeta
ZipWriterClass.__index = ZipWriterClass

function ZipWriterClass.new(): ZipWriter
	return setmetatable({
		_writer = BufferWriter.new(),
		_files = {},
		_offset = 0,
	}, ZipWriterClass)
end

--// API Structure
function ZipWriterClass:addFile(name: string, data: buffer)
	local len = buffer.len(data)
	local crc = computeCRC32(data)

	local entry: ZipFileEntry = {
		name = name,
		data = data,
		crc32 = crc,
		uncompressedSize = len,
		compressedSize = len,
		headerOffset = self._offset,
	}
	table.insert(self._files, entry)

	local w = self._writer

	w:writeUInt32(0x04034b50)
	w:writeUInt16(10) -- version needed to extract (10 = default)
	w:writeUInt16(0) -- general purpose bit flag
	w:writeUInt16(0) -- compression method (0 = store)
	w:writeUInt16(0) -- last mod file time
	w:writeUInt16(0) -- last mod file date
	w:writeUInt32(crc) -- crc-32
	w:writeUInt32(len) -- compressed size
	w:writeUInt32(len) -- uncompressed size
	w:writeUInt16(#name) -- file name length
	w:writeUInt16(0) -- extra field length

	-- We will manually write the string without length prefix (writer:writeString includes len prefix sadly)
	for i = 1, #name do
		w:writeByte(string.byte(name, i))
	end

	w:writeBytes(data)

	self._offset += (30 + #name + len)
end

function ZipWriterClass:getBuffer(): buffer
	local w = self._writer
	local centralDirStart = self._offset

	for _, file in ipairs(self._files) do
		w:writeUInt32(0x02014b50)
		w:writeUInt16(10) -- version made by
		w:writeUInt16(10) -- version needed to extract
		w:writeUInt16(0) -- general purpose bit flag
		w:writeUInt16(0) -- compression method
		w:writeUInt16(0) -- last mod file time
		w:writeUInt16(0) -- last mod file date
		w:writeUInt32(file.crc32) -- crc-32
		w:writeUInt32(file.compressedSize) -- compressed size
		w:writeUInt32(file.uncompressedSize) -- uncompressed size
		w:writeUInt16(#file.name) -- file name length
		w:writeUInt16(0) -- extra field length
		w:writeUInt16(0) -- file comment length
		w:writeUInt16(0) -- disk number start
		w:writeUInt16(0) -- internal file attributes
		w:writeUInt32(0) -- external file attributes
		w:writeUInt32(file.headerOffset) -- relative offset of local header

		for i = 1, #file.name do
			w:writeByte(string.byte(file.name, i))
		end
	end

	local centralDirEnd = w._cursor
	local centralDirSize = centralDirEnd - centralDirStart

	w:writeUInt32(0x06054b50)
	w:writeUInt16(0) -- number of this disk
	w:writeUInt16(0) -- number of the disk with the start of the central directory
	w:writeUInt16(#self._files) -- total number of entries in the central directory on this disk
	w:writeUInt16(#self._files) -- total number of entries in the central directory
	w:writeUInt32(centralDirSize) -- size of the central directory
	w:writeUInt32(centralDirStart) -- offset of start of central directory with respect to the starting disk number
	w:writeUInt16(0) -- .ZIP file comment length

	return w:getBuffer()
end

return ZipWriterClass
