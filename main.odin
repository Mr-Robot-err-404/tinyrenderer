package main

import "core:math"
import "core:os"

Coord :: struct {
	x, y: i32,
}
Vertex :: struct {
	x, y, z: f64,
}
Width: u32 = 1920
Height: u32 = 1080

Triangle :: [3]i32
Cube :: []Vertex {
	{x = 0.5, y = 0.5, z = 2},
	{x = 0.5, y = -0.5, z = 2},
	{x = -0.5, y = 0.5, z = 2},
	{x = -0.5, y = -0.5, z = 2},
	{x = 0.5, y = 0.5, z = 1},
	{x = 0.5, y = -0.5, z = 1},
	{x = -0.5, y = 0.5, z = 1},
	{x = -0.5, y = -0.5, z = 1},
}

main :: proc() {
	buf := make([]u8, Width * Height * 3)
	defer delete(buf)

	// vertices := make(map[Vertex]bool)
	// defer delete(vertices)
	// parse_obj("diablo3_pose.obj", &vertices)

	rasturize(Cube, []Triangle{{0, 1, 2}}, buf)
	write_tga("frame.tga", Width, Height, buf)
}

project :: proc(vertex: Vertex) -> (f64, f64) {
	return vertex.x / vertex.z, vertex.y / vertex.z
}
screen :: proc(ax: f64, ay: f64) -> Coord {
	// -1..1 -> 0..2 -> 0..1 -> 0..w
	x := ((ax + 1) / 2) * (f64(Width) - 0.5)
	y := ((ay + 1) / 2) * (f64(Height) - 0.5)
	return Coord{x = i32(x), y = i32(y)}
}
rasturize :: proc(vertices: []Vertex, triangles: []Triangle, buf: []u8) {
	for t in triangles {
		i, j, k := t[0], t[1], t[2]
		a := screen(project(vertices[i]))
		b := screen(project(vertices[j]))
		c := screen(project(vertices[k]))
		line(a, b, buf, Forest)
		line(c, b, buf, Forest)
		line(a, c, buf, Forest)
	}
	for v in vertices {
		coord := screen(project(v))
		set_pixel(coord.x, coord.y, buf, Red)
	}
}

set_pixel :: proc(x, y: i32, buf: []u8, rgb: [3]u8) {
	idx := (y * i32(Width)) + x
	idx *= 3
	buf[idx] = rgb[2]
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
	for x: i32 = ax; x <= bx; x += 1 {
		t := f32(x - ax) / f32(bx - ax)
		y := f32(ay) + (f32(by - ay) * t)
		if steep {
			set_pixel(i32(y), x, buf, rgb)
			continue
		}
		set_pixel(x, i32(y), buf, rgb)
	}
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
	// header[17] = 0x20

	size := height * width * 3
	data := make([]u8, 18 + size)
	copy(data[:18], header[:])
	copy(data[18:], buffer)
	return os.write_entire_file(filename, data)
}
