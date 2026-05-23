package main

import "core:fmt"
import "core:math"
import "core:os"

Coord :: struct {
	x, y: i32,
}
Vertex :: struct {
	x, y, z: f64,
}
Width: u32 = 64
Height: u32 = 64

main :: proc() {
	buf := make([]u8, Width * Height * 3)
	defer delete(buf)

	// vertices := make(map[Vertex]bool)
	// defer delete(vertices)
	//
	// parse_obj("diablo3_pose.obj", &vertices)

	vertices := [3]Coord{{x = 7, y = 3}, {x = 12, y = 37}, {x = 62, y = 53}}
	render(vertices, buf)
	write_tga("frame.tga", Width, Height, buf)
}

render :: proc(vertices: [3]Coord, buf: []u8) {
	a, b, c := vertices[0], vertices[1], vertices[2]

	line(a, b, buf, Blue)
	line(c, b, buf, Green)
	line(a, c, buf, Red)

	for coord in vertices {
		set_pixel(coord.x, coord.y, buf, White)
	}
}

set_pixel :: proc(x, y: i32, buf: []u8, rgb: [3]u8) {
	idx := (y * i32(Width)) + x
	idx *= 3
	buf[idx] = rgb[2] // blue first!
	buf[idx + 1] = rgb[1]
	buf[idx + 2] = rgb[0]
}

// x(t) = ax + (bx-ax)*t
// t(x) = (x-ax)/(bx-ax)

line :: proc(start: Coord, end: Coord, buf: []u8, rgb: [3]u8) {
	ax, bx := start.x, end.x
	ay, by := start.y, end.y
	steep := math.abs(ax - bx) < math.abs(ay - by)

	if steep {
		swap(&ax, &ay)
		swap(&bx, &by)
	}
	if ax > bx {
		swap(&ax, &bx)
		swap(&ay, &by)
	}
	c := 0
	for x: i32 = ax; x <= bx; x += 1 {
		defer c += 1
		t := f32(x - ax) / f32(bx - ax)
		y := f32(ay) + (f32(by - ay) * t)

		if steep {
			set_pixel(i32(y), x, buf, rgb)
			continue
		}
		set_pixel(x, i32(y), buf, rgb)
	}
	fmt.printf("[%d,%d]:[%d,%d] -> %d\n", start.x, start.y, end.x, end.y, c)
}

swap :: proc(a: ^i32, b: ^i32) {
	tmp := a^
	a^ = b^
	b^ = tmp
}

write_tga :: proc(filename: string, width, height: u32, buffer: []u8) -> bool {
	header := make([]u8, 18)
	header[2] = 2
	header[12] = u8(width & 0xFF)
	header[13] = u8(width >> 8)
	header[14] = u8(height & 0xFF)
	header[15] = u8(height >> 8)
	header[16] = 24
	// origin at top-left
	// header[17] = 0x20

	data := make([]u8, 18 + len(buffer))
	copy(data[:18], header[:])
	copy(data[18:], buffer)
	return os.write_entire_file(filename, data)
}
