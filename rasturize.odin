package main

import "core:math"
import "core:slice"

parallel_rasturize :: proc(triangle: Triangle, vertices: [dynamic]Vertex, buf: []u8, rgb: [3]u8) {
	points := []Coord {
		screen(vertices[triangle[0]].x, vertices[triangle[0]].y),
		screen(vertices[triangle[1]].x, vertices[triangle[1]].y),
		screen(vertices[triangle[2]].x, vertices[triangle[2]].y),
	}
	a, b, c := points[0], points[1], points[2]
	start, end := bounds(a, b, c)

	for x in start.x ..< end.x {
		for y in start.y ..= end.y {
			p := Coord {
				x = x,
				y = y,
			}
			if inside_triangle(
				coord_to_vertex(p),
				coord_to_vertex(a),
				coord_to_vertex(b),
				coord_to_vertex(c),
			) {
				set_pixel(x, y, buf, rgb)
			}
		}
	}
}

// NOTE: Sebastian Lague's epic video -> https://www.youtube.com/watch?v=HYAgJN3x4GA
// P = A + w1(B-A) + w2(C-A)

inside_triangle :: proc(p, a, b, c: Vertex) -> bool {
	w1 := (a.x * (c.y - a.y)) + (p.y - a.y) * (c.x - a.x) - p.x * (c.y - a.y)
	w1 /= (b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y)
	w2 := p.y - a.y - w1 * (b.y - a.y)
	w2 /= c.y - a.y

	if w1 < 0 || w2 < 0 {return false}
	return w1 + w2 <= 1
}

bounds :: proc(a, b, c: Coord) -> (Coord, Coord) {
	return Coord {
		x = min(a.x, b.x, c.x),
		y = min(a.y, b.y, c.y),
	}, Coord{x = max(a.x, b.x, c.x), y = max(a.y, b.y, c.y)}
}

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

coord_to_vertex :: proc(c: Coord) -> Vertex {
	return Vertex{x = f64(c.x), y = f64(c.y)}
}
