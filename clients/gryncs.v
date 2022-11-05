// Copyright(C) 2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module main

import os
import sdl
import sdl.ttf
import flag
import time
import os.font

fn main() {
	mut app := &App{}
	app.init()
	app.run()
	app.quit()
}

const (
	tipsy_work = os.join_path(os.temp_dir(), '.tipsy')
	font_size  = 14
)

struct Text {
mut:
	text        string
	prev_text   string
	has_updates bool
	text_height int
}

fn (mut ti Text) update() {
	if ti.text != ti.prev_text {
		ti.has_updates = true
	}
}

fn (mut ti Text) late_update() {
	if ti.text != ti.prev_text {
		ti.prev_text = ti.text
	}
	ti.has_updates = false
}

struct SDLContext {
pub mut:
	w        int
	h        int
	window   &sdl.Window   = unsafe { nil }
	renderer &sdl.Renderer = unsafe { nil }
	screen   &sdl.Surface  = unsafe { nil }
	texture  &sdl.Texture  = unsafe { nil }
	// Text
	// TTF context for font drawing
	font &ttf.Font = unsafe { nil }
}

struct App {
mut:
	fps_frame    u32
	fps_snapshot u32
	frame        u32
	//
	ready         bool
	shutdown      bool
	runtime_debug bool
	// SDL2 context for drawing
	ui         SDLContext
	text_input Text
	keys_state map[int]bool
	// tipsy context
	tips_dir string
	pid      int
}

fn num_displays() int {
	return sdl.get_num_video_displays()
}

[if debug_gryncs ?]
fn (mut a App) dbg(str string) {
	eprintln(str)
}

fn (a &App) width_and_height() (int, int) {
	window := a.ui.window
	mut w, mut h := 0, 0
	sdl.get_window_size(window, &w, &h)
	return w, h
}

fn (mut a App) init() {
	$if debug ? {
		a.runtime_debug = true
	}

	mut fp := flag.new_flag_parser(os.args)
	fp.application('gryncs')
	fp.version('v0.1.0')
	fp.description('Gryncs a simple tipsy context graphical client')

	fp.skip_executable()

	a.pid = fp.int('pid', 0, 0, 'Read context from <pid> tipsy process')

	a.tips_dir = fp.string('tips', 0, '', 'Path to tips')
	if !os.is_dir(a.tips_dir) {
		panic('Tips directory "$a.tips_dir" doesn\'t exist')
	}

	fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	$if linux {
		// Stops the brief flickering when window opens/closes + the browser canvas going blank
		sdl.set_hint(sdl.hint_video_x11_net_wm_bypass_compositor.str, '0'.str)
	}
	sdl.init(sdl.init_video)
	ttf.init()

	mut mx := 0
	mut my := 0
	sdl.get_global_mouse_state(&mx, &my)

	mut display_number := 0

	displays := num_displays()
	// println('Displays: $displays')
	// get display bounds for all displays
	mut display_bounds := []sdl.Rect{}
	for i in 0 .. displays {
		mut display_bound := sdl.Rect{}
		sdl.get_display_bounds(i, &display_bound)

		mp := sdl.Point{mx, my}
		if sdl.point_in_rect(&mp, &display_bound) {
			display_number = i
		}
		display_bounds << display_bound
	}
	// println('Bounds: $display_bounds')

	// TODO
	$if debug_gryncs ? {
		dn := unsafe { cstring_to_vstring(sdl.get_display_name(display_number)) }
		a.dbg('Opening on screen $display_number "$dn" ($mx,$my)')
	}

	// display := sdl.get_window_display_index(window)

	a.ui.font = ttf.open_font(font.get_path_variant(font.default(), .mono).str, font_size)
	mut txt_w, mut txt_h := 0, 0
	ttf.size_utf8(a.ui.font, 'Åj'.str, &txt_w, &txt_h)

	a.text_input.text_height = txt_h
	win_h := txt_h * 16
	win_w := (display_bounds[display_number].w / 3) - 60

	x := display_bounds[display_number].x + display_bounds[display_number].w - win_w
	y := display_bounds[display_number].y

	window := sdl.create_window('gryncs'.str, x, y, win_w, win_h, u32(sdl.WindowFlags.borderless) | u32(sdl.WindowFlags.skip_taskbar))
	//| u32(sdl.WindowFlags.resizable)
	renderer := sdl.create_renderer(window, -1, u32(sdl.RendererFlags.accelerated)) //| u32(sdl.RendererFlags.presentvsync)

	sdl.set_render_draw_blend_mode(renderer, .blend)

	// println(ptr_str(a.ui.font))
	a.ui.window = window
	a.ui.renderer = renderer

	a.ready = true
}

fn (a App) is_key_held(keycode sdl.KeyCode) bool {
	/*
	TODO if kc := a.keys_state[keycode] {
		return a.keys_state[keycode]
	}
	return false
	*/
	return int(keycode) in a.keys_state.keys() && a.keys_state[int(keycode)]
}

fn (mut a App) run() {
	// window := a.ui.window
	renderer := a.ui.renderer

	mut fps_timer := u32(0)

	// a.shutdown := false
	for {
		// start := sdl.get_performance_counter()

		if !a.ready {
			time.sleep(1 * time.second)
			continue
		}
		a.process_events()

		if a.shutdown {
			break
		}

		now := sdl.get_ticks()
		// count fps in 1 sec (1000 ms)
		if now > fps_timer + 1000 {
			fps_timer = now
			a.fps_snapshot = a.fps_frame
			a.fps_frame = 0
		}
		a.fps_frame++

		sdl.set_render_draw_color(renderer, 49, 54, 59, 255)
		sdl.render_clear(renderer)

		a.update()

		a.draw()

		// end := sdl.get_performance_counter()
		// elapsed_ms := f32(end - start) / f32(sdl.get_performance_frequency()) * 1000.0

		// Cap to 60 FPS
		// println(u32(math.floor(16.666 - elapsed_ms)))
		// sdl.delay(u32(math.floor(16.666 - elapsed_ms)))

		sdl.render_present(renderer)

		a.frame++

		sdl.delay(2000)

		a.text_input.late_update()
	}
}

fn (mut a App) update() {
	mut tpid := 0
	mut app := ''

	mut running := os.ls(tipsy_work) or { panic(err) }

	for running.len <= 0 {
		time.sleep(2000 * time.millisecond)
		running = os.ls(tipsy_work) or { panic(err) }
		continue
	}

	if tpid == 0 && running[0].int() != tpid {
		if a.pid > 0 {
			for spid in running {
				if spid.int() == a.pid {
					tpid = a.pid
				}
			}
		}
		if tpid == 0 {
			tpid = running[0].int()
		}
		// println('Using tipsy instance $tpid')
	}

	context_dir := os.join_path(tipsy_work, tpid.str(), 'context')

	alias := os.read_file(os.join_path(context_dir, 'alias')) or { '' }
	mut tapp := os.read_file(os.join_path(context_dir, 'app')) or { return }
	if alias != '' {
		tapp = alias
	}
	if tapp != app {
		app = tapp

		app_file := os.join_path(a.tips_dir, '$app')
		if os.exists(app_file) {
			tip := os.read_file(app_file) or { return }
			a.text_input.text = tip
		} else {
			a.text_input.text = 'No tip for $app'
		}
	}

	a.text_input.update()
}

fn (mut a App) draw() {
	a.draw_text_input()

	if a.runtime_debug {
		win_w, _ := a.width_and_height()
		ch_w, _ := a.rendered_text_size('$a.fps_snapshot')
		a.draw_text_at('$a.fps_snapshot', win_w - ch_w, 0, sdl.Color{55, 255, 255, 127})
	}
}

fn (mut a App) process_events() {
	evt := sdl.Event{}
	for 0 < sdl.poll_event(&evt) {
		match evt.@type {
			.quit {
				a.shutdown = true
			}
			.windowevent {
				// if sdl.WindowEventID(int(evt.window.event)) == .focus_lost {
				//	a.shutdown = true
				//}
			}
			.keyup {
				a.keys_state[int(evt.key.keysym.sym)] = false
			}
			.keydown {
				a.keys_state[int(evt.key.keysym.sym)] = true
				key := unsafe { sdl.KeyCode(evt.key.keysym.sym) }
				// a.dbg('${sdl.get_key_name(evt.key.keysym.sym)} / $key pressed')

				is_ctrl_held := a.is_key_held(.lctrl) || a.is_key_held(.rctrl)
				match key {
					.escape {
						// if is_ctrl_held {
						a.shutdown = true
						break
						//}
					}
					.d {
						if is_ctrl_held {
							a.runtime_debug = !a.runtime_debug
							eprintln('Runtime debugging: $a.runtime_debug')
						}
					}
					else {
						if !a.runtime_debug {
							return
						}

						if key == .f1 {
							/*
							window := a.ui.window
							w, h := a.width_and_height()
							win_h := a.text_input.text_height + 2
							*/
						}

						if key == .f2 {
						}
					}
				}
			}
			else {}
		}
	}
}

fn (mut a App) quit() {
	sdl.destroy_renderer(a.ui.renderer)
	sdl.destroy_window(a.ui.window)
	ttf.close_font(a.ui.font)
	sdl.quit()
}

fn (mut a App) draw_text_input() {
	// if !a.text_input.has_updates {
	//	return
	//}
	// rdr := a.ui.renderer
	// win_w, win_h := a.width_and_height()

	txt := a.text_input.text

	// txt_h := a.text_input.text_height

	// gutter_rect := sdl.Rect{0, 0, win_w, win_h}

	/*
	sdl.set_render_draw_color(rdr, 35, 38, 41, 255)
	sdl.render_fill_rect(rdr, &gutter_rect)
	*/

	// sdl.set_render_draw_color(rdr, 255, 255, 255, 64)
	// sdl.render_draw_rect(rdr, &gutter_rect)

	if txt.trim(' ') != '' {
		a.draw_text_at(txt, 1, 1, sdl.Color{255, 255, 255, 200})
	}
}

fn (a &App) draw_text_at(text string, x int, y int, color sdl.Color) {
	if !isnil(a.ui.font) {
		win_w, _ := a.width_and_height()
		sf := ttf.render_utf8_blended_wrapped(a.ui.font, text.str, color, u32(win_w))
		if isnil(sf) {
			return
		}
		texture := sdl.create_texture_from_surface(a.ui.renderer, sf)
		texw := 0
		texh := 0
		u32null := u32(0)
		intnull := 0
		sdl.query_texture(texture, &u32null, &intnull, &texw, &texh)
		dst_rect := sdl.Rect{x, y, texw, texh}
		sdl.render_copy(a.ui.renderer, texture, sdl.null, &dst_rect)
		sdl.destroy_texture(texture)
		sdl.free_surface(sf)
	} else {
		panic('no font')
	}
}

fn (a &App) rendered_text_size(text string) (int, int) {
	if !isnil(a.ui.font) {
		sf := ttf.render_utf8_blended(a.ui.font, text.str, sdl.Color{255, 255, 255, 255})
		texture := sdl.create_texture_from_surface(a.ui.renderer, sf)
		texw := 0
		texh := 0
		u32null := u32(0)
		intnull := 0
		sdl.query_texture(texture, &u32null, &intnull, &texw, &texh)
		// dst_rect := sdl.Rect{x, y, texw, texh}
		// sdl.render_copy(a.ui.renderer, texture, sdl.null, &dst_rect)
		sdl.destroy_texture(texture)
		sdl.free_surface(sf)
		return texw, texh
	} else {
		panic('no font')
	}
}
