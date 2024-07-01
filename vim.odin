package main

import im "./odin-imgui"
import      "base:runtime"
import "core:c/libc"
import "core:os"
import "core:c"
import strings "core:strings"
import "core:fmt"

import "./odin-imgui/imgui_impl_glfw"
import "./odin-imgui/imgui_impl_opengl3"

VimMode :: enum{
	Insert,
	Normal,
	Visual,
	Replace,
	Command,
	CommandSearch,
	ListFiles,
}

VimState :: struct{
	mode : VimMode,

    selection : [2]u32, //start and end position of selection
}

vim_process_char_normal_mode :: proc(c : rune){
    switch c{
    case 'i':{
        app.mode = .Insert
    }
    case 'a':{
        gapbuf_frontward(&app.gap_buf)
        app.mode = .Insert
        redraw = true
    }
    case '/':{
        app.mode = .ListFiles
    }

	case 'h':{
		gapbuf_backward(&app.gap_buf)
		redraw = true
	}
	case 'k':{
		gapbuf_up(&app.gap_buf)
		redraw = true
	}
	case 'j':{
		gapbuf_down(&app.gap_buf)
		redraw = true
	}

	case 'l':{
		gapbuf_frontward(&app.gap_buf)
		redraw = true
	}
    case ':':{
        if is_down(.SHIFT){
            app.mode = .Command
        }
    }

    case 'w':{
        gapbuf_jump_next_word(&app.gap_buf)
        redraw = true
    }

    case 'b':{
        gapbuf_jump_prev_word(&app.gap_buf)
        redraw = true
    }

    case 'v':{
        app.mode = .Visual;
    }

    }
}

vim_process_key :: proc(){
    if app.mode == .Insert{
        if is_pressed(.F1){
            im.SetWindowFocusStr("Command"); 
        }
        if is_down(.BACK){
            gapbuf_backspace(&app.gap_buf)
            redraw = true
        }
        if is_pressed(.ENTER){
            gapbuf_insert(&app.gap_buf, '\n')
            redraw = true
        }
        if is_pressed(.TAB){
            gapbuf_insert(&app.gap_buf, '\t')
            redraw = true
        }
        if is_down(.ACTION_LEFT){
            gapbuf_backward(&app.gap_buf)
            redraw = true
        }
        if is_pressed(.ACTION_UP){
            gapbuf_up(&app.gap_buf)
            redraw = true
        }
        if is_pressed(.ACTION_DOWN){
            gapbuf_down(&app.gap_buf)
            redraw = true
        }

		if is_down(.ACTION_RIGHT){
			gapbuf_frontward(&app.gap_buf)
			redraw = true
        }

        if is_pressed(.ESCAPE){
            gapbuf_backward(&app.gap_buf)
            app.mode = .Normal
            redraw = true
        }
    }
}






