package main

import "core:math"
import "core:os"

Step :: enum {
	Wireframe,
	Rasturization,
}
Coord :: struct {
	x, y: i32,
}
Vertex :: struct {
	x, y, z: f64,
}
Vec4 :: struct {
	using vertex: Vertex,
	w:            f64,
}
Width: u32 = 800
Height: u32 = 800

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
step := Step.Rasturization
Focal_Distance: f64 = 3

main :: proc() {
	buf := make([]u8, Width * Height * 3)
	depth := make([]u8, Width * Height * 3)
	z_buf := make([]f64, Width * Height)
	defer delete(buf)
	defer delete(depth)
	defer delete(z_buf)

	vertices := make([dynamic]Vertex)
	triangles := make([dynamic]Triangle)
	defer delete(vertices)
	defer delete(triangles)

	parse_obj("head.obj", &vertices, &triangles)

	switch step {
	case Step.Wireframe:
		rasturize(vertices, triangles, buf, Red)
		write_tga("frame.tga", Width, Height, buf)
	case Step.Rasturization:
		view := make([]f64, 16)
		modal(Center, Eye, Up, view)

		pp := perspective(Eye, Center)
		vp := viewport(0, 0)
		persp := make([]f64, 16)
		pipeline := make([]f64, 16)

		compose(pp[:], vp[:], 4, persp)
		compose(view, persp, 4, pipeline)

		for triangle in triangles {
			parallel_rasturize(pipeline, triangle, vertices, buf, depth, z_buf, rnd_color())
		}
		write_tga("pixels.tga", Width, Height, buf)
		write_tga("depth.tga", Width, Height, depth)
	}
}

project :: proc(vertex: Vertex) -> (f64, f64) {
	z := vertex.z + 1.5
	return vertex.x / z, vertex.y / z
}
screen :: proc(v: Vertex) -> Coord {
	// -1..1 -> 0..2 -> 0..1 -> 0..w
	perspective := 1 / (1 - v.z / Focal_Distance)
	x := math.round_f64(((v.x * perspective + 1) / 2) * (f64(Width) - 0.5))
	y := math.round_f64(((v.y * perspective + 1) / 2) * (f64(Height) - 0.5))
	return Coord{x = i32(x), y = i32(y)}
}


rasturize :: proc(vertices: [dynamic]Vertex, triangles: [dynamic]Triangle, buf: []u8, rgb: [3]u8) {
	for t in triangles {
		i, j, k := t[0], t[1], t[2]
		a := screen(vertices[i])
		b := screen(vertices[j])
		c := screen(vertices[k])
		line(a, b, buf, rgb)
		line(c, b, buf, rgb)
		line(a, c, buf, rgb)
	}
	for v in vertices {
		coord := screen(v)
		set_pixel(coord.x, coord.y, buf, White)
	}
}


set_pixel :: proc(x, y: i32, buf: []u8, rgb: [3]u8) {
	idx := (y * i32(Width)) + x
	idx *= 3
	if idx < 0 || idx >= i32(len(buf)) {return}

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
		y := math.round_f32(f32(ay) + (f32(by - ay) * t))
		if steep {
			set_pixel(i32(y), x, buf, rgb)
			continue
		}
		set_pixel(x, i32(y), buf, rgb)
	}
}

swap :: proc(a: ^$T, b: ^T) {
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
