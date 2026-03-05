--!strict

--// Types
export type MapMetadata = {
	Artist: string,
	AudioExt: string,
	Difficulty: number,
	DifficultyName: string,
	HasAudio: boolean,
	HasCover: boolean,
	HasVideo: boolean,
	ID: string,
	Mappers: { string },
	Rating: number,
	Title: string,
}

export type Note = {
	x: number,
	y: number,
	ms: number,
}

export type VfxObject = {
	typeId: number,
	timestamp: number,
	params: { any },
}

export type RhythiaMap = {
	metadata: MapMetadata,
	soundId: string,
	notes: { Note },
	vfxObjects: { VfxObject },
}

return {}
