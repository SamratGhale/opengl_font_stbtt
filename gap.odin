package main

import "core:mem"
import intr "base:intrinsics"
import "core:strings"

GapBuf :: struct {
    buf : []u8,

    //Gap is the amount of gap there is
    //front is the position of the front
    //total is the total length of buffer
    total, front, gap: u32,
}

gapbuf_init :: proc(b: ^GapBuf, init: u32){
    b.total = init
    b.gap   = init
    b.buf,_ = mem.alloc_bytes(int(init))
}

gapbuf_destroy :: proc(b: ^GapBuf){
    mem.free_bytes(b.buf)
    b.buf = nil
}

//insert at the front of the gap
gapbuf_insert :: proc(b: ^GapBuf, c: u8){
    if b.gap == 0{
	back    := b.total - b.front
	b.gap    = b.total
	b.total *=2 
	intr.mem_copy_non_overlapping(&b.buf[0], &b.buf[0], b.total)
	intr.mem_copy(&b.buf[b.front+b.gap], &b.buf[b.front], back)
    }

    b.buf[b.front] = c
    b.front +=1
    b.gap   -=1
}

gapbuf_inserts :: proc(b: ^GapBuf, s: []u8){

    strlen :u32= u32(len(s))
    back   := b.total - b.front - b.gap

    for b.gap < u32(strlen){
	b.gap = 0
	gapbuf_insert(b, 0)
	b.front -= 1
	b.gap   += 1
    }
    intr.mem_copy_non_overlapping(&b.buf[b.front], &s[0], b.total)
    b.front += strlen
    b.gap    = b.total - b.front - back
}


//move the gap
gapbuf_move :: proc(b: ^GapBuf, amt : i32){
    strlen : i32

    dst, src : rawptr
    if amt < 0{
	strlen = -amt
	if strlen > i32(b.front){
	    strlen = i32(b.front)
	}

	dst = &b.buf[i32(b.front + b.gap) - strlen]
	dst = &b.buf[i32(b.front) - strlen]
	b.front -= u32(strlen)
    }else{
	back := b.total - b.front - b.gap
	strlen = amt

	if strlen > i32(back){
	    strlen = i32(back)
	}

	dst = &b.buf[b.front]
	src = &b.buf[b.front + b.gap]
	b.front += u32(strlen)
    }
    intr.mem_copy(dst, src, strlen)
}

gapbuf_backward :: proc(b: ^GapBuf){
    if b.front > 0{
	//very neat
	b.buf[b.front + b.gap - 1] = b.buf[b.front -1]
	b.front-=1
    }
}

//delete like del
gapbuf_delete :: proc(b: ^GapBuf){
    if b.total > b.front + b.gap{
	b.gap += 1
    }
}

//move like backspace
gapbuf_backspace :: proc(b: ^GapBuf){
    if b.front > 0{
	b.front -=1
	b.gap   += 1
    }
}

//delete like backspace
gapbuf_frontward:: proc(b: ^GapBuf){
    if b.front < b.total {
	b.buf[b.front] = b.buf[b.front+ b.gap]
	b.front+=1
    }
}

//Returns the string to be rendered of the gap buffer
get_string :: proc(g: ^GapBuf) -> string{
	using strings
	builder : Builder
	builder_init_none(&builder)

	write_bytes(&builder, g.buf[0:g.front])
	write_bytes(&builder, g.buf[int(g.front + g.gap): g.total])

	res := to_string(builder)
	return res
}











