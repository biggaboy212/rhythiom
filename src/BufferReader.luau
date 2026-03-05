--!strict

--// Types
export type BufferReader = typeof(setmetatable(
	{} :: {
		_buffer: buffer,
		_cursor: number,
	},
	{} :: BufferReaderMeta
))

type BufferReaderMeta = {
	__index: BufferReaderMeta,
	new: (buf: buffer) -> BufferReader,
	readInt32: (self: BufferReader) -> number,
	readUInt32: (self: BufferReader) -> number,
	readUInt16: (self: BufferReader) -> number,
	readByte: (self: BufferReader) -> number,
	readBoolean: (self: BufferReader) -> boolean,
	readSingle: (self: BufferReader) -> number,
	readBytes: (self: BufferReader, length: number) -> buffer,
	readString: (self: BufferReader) -> string,
	getCursor: (self: BufferReader) -> number,
	setCursor: (self: BufferReader, pos: number) -> (),
}

--// Constructor
local BufferReader = {} :: BufferReaderMeta
BufferReader.__index = BufferReader

function BufferReader.new(buf: buffer): BufferReader
	return setmetatable({
		_buffer = buf,
		_cursor = 0,
	}, BufferReader)
end

--// Public Methods
function BufferReader:readInt32(): number
	local val = buffer.readi32(self._buffer, self._cursor)
	self._cursor += 4
	return val
end

function BufferReader:readUInt32(): number
	local val = buffer.readu32(self._buffer, self._cursor)
	self._cursor += 4
	return val
end

function BufferReader:readUInt16(): number
	local val = buffer.readu16(self._buffer, self._cursor)
	self._cursor += 2
	return val
end

function BufferReader:readByte(): number
	local val = buffer.readu8(self._buffer, self._cursor)
	self._cursor += 1
	return val
end

function BufferReader:readBoolean(): boolean
	local val = buffer.readu8(self._buffer, self._cursor)
	self._cursor += 1
	return val ~= 0
end

function BufferReader:readSingle(): number
	local val = buffer.readf32(self._buffer, self._cursor)
	self._cursor += 4
	return val
end

function BufferReader:readBytes(length: number): buffer
	local slice = buffer.create(length)
	buffer.copy(slice, 0, self._buffer, self._cursor, length)
	self._cursor += length
	return slice
end

function BufferReader:readString(): string
	local length = self:readUInt16()
	local str = buffer.readstring(self._buffer, self._cursor, length)
	self._cursor += length
	return str
end

function BufferReader:getCursor(): number
	return self._cursor
end

function BufferReader:setCursor(pos: number)
	self._cursor = pos
end

return BufferReader
