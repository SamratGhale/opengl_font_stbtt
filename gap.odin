package main

import "core:mem"
import "core:os"
import intr "base:intrinsics"
import "core:fmt"
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

gapbuf_init_file :: proc(b: ^GapBuf, file_path: string){
    data, ok := os.read_entire_file_from_filename(file_path)


    //gapbuf_inserts(b, data)

    if ok{
    	data_len := len(data)
    	b.total = u32(data_len + 200)
    	b.gap = 200
    	//b.front = 0
    	b.front = 0
    	b.buf,_ = mem.alloc_bytes(data_len + 200)
	    //mem.
	    intr.mem_copy(&b.buf[200], &data[0], data_len)

    }else{
    	fmt.println("Failed to read file")
    	gapbuf_init(b, 200)
    }
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

		new_buff,_ := mem.alloc_bytes(int(b.total))

		intr.mem_copy_non_overlapping(&new_buff[0], &b.buf[0], b.total)
		b.buf = new_buff
		if back != 0{
			intr.mem_copy(&b.buf[b.front+b.gap], &b.buf[b.front], back)
		}
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
    	src = &b.buf[i32(b.front) - strlen]
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
	if  b.front + b.gap < b.total{
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




//get's the list of newlines's position in the string
get_rows :: proc(str: string)->[dynamic]u32{
	ret := make([dynamic]u32, 0, 10)

	append(&ret, 0) //always starts with 0
	for r , i in str{
		if r == '\n'{
			append(&ret, u32(i))
		}
	}
	return ret
}

// Get current row and column
// Find the length of the previous row
// move -min(column, len_of_previous_row)

gapbuf_up :: proc(b: ^GapBuf){
	row, column := gapbuf_get_curr_pos(b)

	if row == 0 do return

	str := get_string(b)
	rows := get_rows(str)

	add_offset :i32= i32(row-1) == 0 ? 1 : 0 //because first row dosen't have \n
	len_of_prev_row :i32= max(i32(column), i32(rows[row]) - i32(rows[row-1]))  + add_offset

	gapbuf_move(b, -len_of_prev_row)
}

//Get current row and column
//Find the length of the next row
//move to min(column, )
gapbuf_down :: proc(b: ^GapBuf){
	row, column := gapbuf_get_curr_pos(b)


	str  := get_string(b)
	rows := get_rows(str)

	if int(row) == len(rows) -1 do return

	add_offset :i32= i32(row) == 0 ? 1 : 0 //because first row dosen't have \n
	len_of_prev_row :i32= max(i32(column), i32(rows[row+1]) - i32(rows[row])) + add_offset

	gapbuf_move(b, len_of_prev_row)
}


//row, column
gapbuf_get_curr_pos :: proc(b: ^GapBuf)-> (u32, u32){
	str := get_string(b)

	rows := get_rows(str)

	row : u32
	column : u32

	if len(rows) <= 1 do return  0, b.front

	for r, i in rows{

		if b.front >= r{
			if i < len(rows)-1{
				if b.front < rows[i+1] {
					column = b.front - r
					row = u32(i)
					break
				}
			}else{
				row = u32(i)
				column = b.front - r
			}
		}
	}

	return row, column
}


















