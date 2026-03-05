# Rhythiom

Rhythiom is a Luau library that aims to provide a API access layer to create and edit Rhythia maps (PHXM, SSPM, ...) files. 

## Quickstart

The best way to get started is reading [an example](tests\maps\cant-go-broke\generator.test.luau).

### How do I run this?

To run this, you need [lune](https://github.com/lune-org/lune). You can install it via [aftman](https://github.com/LPGhatguy/aftman) or something similar.

Lune is a Luau runtime, it lets you run our API.

```bash
lune run <path_to_your_generator>
```

### Initializing the API
```lua
local Map = require("./src").Map

-- Create an new `RhythiaMap` object
local map = Map.new({
    Artist = "ZEDDY WILL",
	Difficulty = 4,
	DifficultyName = "Insane",
    Title = "Cant Go Broke",
    -- ... other metadata
})
```

### Loading existing Maps

```lua
local map = Map.load("./path/to/extracted/map/directory")
```

### Working with Notes

Rhythiom has support for quantum coords:

```lua 
-- Standard
map:addNote(1, 1, 1500)

-- Quantum
map:addNote(0.5, -0.35, 1250)
```

### Embedding & Exporting

```lua
-- Attach audio
map:setAudio("C:/Path/To/Audio.mp3")

-- Export in SSPM format
map:save("./test_map.sspm")

-- Export in PHXM format (this is used in rhythia rewrite)
map:save("./test_map.phxm")
```