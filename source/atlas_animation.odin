package game

import "core:fmt"
import rl "vendor:raylib"

AnimationFromAtlas :: struct {
	atlas_anim:    Animation_Name,
	current_frame: Texture_Name,
	timer:         f32,
	goingForward:  bool,
	times:         u16,
}

animation_create :: proc(anim: Animation_Name) -> AnimationFromAtlas {
	a := atlas_animations[anim]

	return {
		current_frame = a.first_frame,
		atlas_anim = anim,
		timer = atlas_textures[a.first_frame].duration,
		goingForward = true,
		times = a.repeat,
	}
}

animation_update :: proc(a: ^AnimationFromAtlas, dt: f32) -> bool {
	a.timer -= dt
	looped := false


	if a.timer <= 0 {
		anim := atlas_animations[a.atlas_anim]
		//fmt.println("an: %v times %v repeat", a.atlas_anim, a.times, anim.repeat, a.current_frame)
		switch anim.loop_direction {
		case .Forward:
			//fmt.println("previous frame ", Texture_Name(int(a.current_frame)))
			a.current_frame = Texture_Name(int(a.current_frame) + 1)


			//fmt.println("current frame ", a.current_frame)


			if a.current_frame > anim.last_frame {

				if (a.times > 1) {

					a.times -= 1
					if a.times == 0 {
						a.times = 0
						a.current_frame = Texture_Name(int(anim.last_frame))
						looped = true
						fmt.println("Looped a.times < 0 LAST FRAME ", a.current_frame)
					} else {

						a.current_frame = Texture_Name(int(anim.first_frame))
						//fmt.println("back to the first frame with a.times >= 0", a.current_frame)
					}

					//fmt.println("new a.times ", a.times)
				} else {
					a.current_frame = Texture_Name(int(anim.first_frame))
					//fmt.println("back to the first frame with a.times >= 0", a.current_frame)
					looped = true
				}


			}


		case .Reverse:
			a.current_frame = Texture_Name(int(a.current_frame) - 1)

			if a.current_frame < anim.first_frame {
				a.current_frame = anim.last_frame
				looped = true
			}
		case .Ping_Pong:
			dir := 1
			if !a.goingForward {
				dir = -1
			}

			a.current_frame = Texture_Name(int(a.current_frame) + 1 * dir)

			if a.current_frame > anim.last_frame {
				a.current_frame = Texture_Name(int(a.current_frame) - 2)
				a.goingForward = false
			} else if a.current_frame < anim.first_frame {
				a.current_frame = Texture_Name(int(a.current_frame) + 2)
				looped = true
				a.goingForward = true
			}


		case .Ping_Pong_Reverse:
			dir := 1
			if !a.goingForward {
				dir = -1
			}
			a.current_frame = Texture_Name(int(a.current_frame) + 1 * dir)

			if a.current_frame > anim.last_frame {
				a.current_frame = Texture_Name(int(a.current_frame) - 2)
				a.goingForward = false
			} else if a.current_frame < anim.first_frame {
				a.current_frame = Texture_Name(int(a.current_frame) + 2)
				looped = true
				a.goingForward = true
			}
		}


		a.timer = atlas_textures[a.current_frame].duration
	}

	return looped
}

animation_length :: proc(anim: Animation_Name) -> f32 {
	l: f32
	aa := atlas_animations[anim]

	for i in aa.first_frame ..= aa.last_frame {
		t := atlas_textures[i]
		l += t.duration
	}

	return l
}

animation_atlas_draw :: proc(
	anim: AnimationFromAtlas,
	pos: rl.Vector2,
	flip: bool,
	tint: rl.Color = rl.WHITE,
) -> rl.Rectangle {
	if anim.current_frame == .None {
		fmt.println("No animation to draw")
		return rl.Rectangle{x = 0, y = 0, width = 0, height = 0}
	}

	texture := atlas_textures[anim.current_frame]

	atlas_rect := texture.rect

	// The texture has four offset fields: offset_top, right, bottom and left. The offsets records
	// the distance between the pixels in the atlas and the edge of the original document in the
	// image editing software. Since the atlas is tightly packed, any empty pixels are removed.
	// These offsets can be used to correct for that removal.
	//
	// This can be especially obvious in animations where different frames can have different
	// amounts of empty pixels around it. By adding the offsets everything will look OK.
	//
	// If you ever flip the animation in X or Y direction, then you might need to add the right or
	// bottom offset instead.
	offset_pos := rl.Vector2{texture.offset_left, texture.offset_top}

	//rl.DrawTextureRec(atlas, texture.rect, offset_pos, rl.WHITE)

	if flip {
		atlas_rect.width = -atlas_rect.width
		offset_pos.x = texture.offset_right
		//offset_pos.y = texture.offset_bottom


	}


	draw_dest := rl.Rectangle {
		x      = pos.x + offset_pos.x,
		y      = pos.y + offset_pos.y,
		width  = texture.rect.width,
		height = texture.rect.height,
	}

	/*origin := rl.Vector2 {
		texture.document_size.x / 2,
		0, // -1 because there's an outline in the player anim that takes an extra pixel
	}*/


	/*origin := rl.Vector2 {
		texture.document_size.x / 2,
		texture.document_size.y - 1, // -1 because there's an outline in the player anim that takes an extra pixel
	}*/

	rl.DrawTexturePro(g.atlas, atlas_rect, draw_dest, 0, 0, tint)

	return atlas_rect
}

animation_atlas_texture :: proc(anim: AnimationFromAtlas) -> Atlas_Texture {
	return atlas_textures[anim.current_frame]
}
