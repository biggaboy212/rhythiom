local Map = require("@src").Map

local map = Map.new({
	Artist = "Zeddy Will",
	AudioExt = "mp3",
	Difficulty = 4,
	DifficultyName = "Insane",
	HasCover = false,
	HasVideo = false,
	ID = "blehhejasdhlksadhlksadhlasdhl",
	Mappers = { "biggaboy212" },
	Rating = 8,
	Title = "Cant Go Broke - Remix",
})

map:setAudio("./tests/maps/cant-go-broke/audio.mp3")

local msPerNote = 100
local notes = 1000

for i = 0, notes - 1 do
	local ms = i * msPerNote
	local radius = (i / notes) * 1.5
	local angle = i * 0.5

	local x = 1.0 + math.cos(angle) * radius
	local y = 1.0 + math.sin(angle) * radius

	map:addNote(x, y, ms)
end

map:save("./tests/maps/cant-go-broke/generated/cant-go-broke.sspm")
map:save("./tests/maps/cant-go-broke/generated/cant-go-broke.phxm")
