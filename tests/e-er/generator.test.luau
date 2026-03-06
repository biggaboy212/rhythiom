local Map = require("@src").Map
local fs = require("@lune/fs")
local json = require("@lune/serde").decode

local MAP_NAME = "e-er"
local AUDIO_PATH = `./tests/{MAP_NAME}/audio.mp3`
local DATA_PATH  = `./tests/{MAP_NAME}/beatmapData.json`
local OUT_DIR    = "./generated"
local OUT_STEM   = MAP_NAME

local raw = fs.readFile(DATA_PATH)
local data = json("json", raw)

local map = Map.new({
    Artist       = data.artist,
    AudioExt     = data.audioExt or "mp3",
    Difficulty   = data.difficulty,
    DifficultyName = data.difficultyName,
    HasCover     = false,
    HasVideo     = false,
    ID           = data.id,
    Mappers      = data.mappers,
    Rating       = data.rating,
    Title        = data.title,
})

map:setAudio(AUDIO_PATH)

for _, note in ipairs(data.notes) do
    map:addNote(note[1], note[2], note[3])
end

map:save(OUT_DIR .. "/" .. OUT_STEM .. ".sspm")
map:save(OUT_DIR .. "/" .. OUT_STEM .. ".phxm")

print("Saved " .. #data.notes .. " notes → " .. OUT_DIR .. "/" .. OUT_STEM)