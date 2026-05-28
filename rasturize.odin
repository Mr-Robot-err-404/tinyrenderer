package main

import "core:math"
import "core:slice"

scanline_rasturize :: proc(triangle: Triangle, vertices: [dynamic]Vertex, buf: []u8) {
	points := []Coord {
		screen(vertices[triangle[0]].x, vertices[triangle[0]].y),
		screen(vertices[triangle[1]].x, vertices[triangle[1]].y),
		screen(vertices[triangle[2]].x, vertices[triangle[2]].y),
	}
	slice.sort_by(points, proc(a, b: Coord) -> bool {
		return a.y < b.y
	})
	a, b, c := points[0], points[1], points[2]

	if b.x > c.x {swap(&b, &c)}
	line(a, b, buf, Forest)
	line(a, c, buf, Blue)
	line(b, c, buf, Yellow)

	y := a.y
	for y <= b.y && y <= c.y {
		defer y += 1
		start := sample_at(y, a, b)
		end := sample_at(y, a, c)

		for x := start + 1; x < end; x += 1 {
			set_pixel(x, y, buf, Steel_Blue)
		}
	}
	if b.y > c.y {swap(&b, &c)}

	a = Coord {
		x = sample_at(y, a, c),
		y = y,
	}
	if a.x > b.x {swap(&a, &b)}

	floor := y
	for y := c.y; y >= floor; y -= 1 {
		start := sample_at(y, c, a)
		end := sample_at(y, c, b)

		for x := start + 1; x < end; x += 1 {
			set_pixel(x, y, buf, Mint)
		}
	}
}

sample_at :: proc(y: i32, a, b: Coord) -> i32 {
	ax, bx := a.x, b.x
	ay, by := a.y, b.y

	if ax > bx {
		swap(&ax, &bx)
		swap(&ay, &by)
	}
	t := f32(y - ay) / f32(by - ay)
	x := f32(ax) + (f32(bx - ax) * t)
	return i32(math.round_f32(x))
}
