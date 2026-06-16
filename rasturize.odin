package main

import "core:math"
import "core:slice"

Axis :: enum {
	X,
	Y,
	Z,
}
Angle: f64 = -math.PI / 6

parallel_rasturize :: proc(
	triangle: Triangle,
	vertices: [dynamic]Vertex,
	buf: []u8,
	depth: []u8,
	z_buf: []f64,
	rgb: [3]u8,
) {
	transformation := compose_matrices(
		rotation_matrix(Angle, Axis.Y),
		rotation_matrix(Angle, Axis.X),
	)
	transformation = compose_matrices(transformation, rotation_matrix(Angle, Axis.Z))
	va, vb, vc := vertices[triangle[0]], vertices[triangle[1]], vertices[triangle[2]]
	points := []Coord {
		screen(transform(transformation, va)),
		screen(transform(transformation, vb)),
		screen(transform(transformation, vc)),
		// screen(rotate(va, Axis.Y, Angle)),
		// screen(rotate(vb, Axis.Y, Angle)),
		// screen(rotate(vc, Axis.Y, Angle)),
	}
	bnd := z_bounds(vertices)

	a, b, c := points[0], points[1], points[2]
	ensure_unique_apex(&a, &b, &c)
	area := triangle_area(coord_to_vertex(a), coord_to_vertex(b), coord_to_vertex(c))
	if area < 1 {return}

	start, end := bounds(a, b, c)
	for x in start.x ..= end.x {
		for y in start.y ..= end.y {
			p := Coord {
				x = x,
				y = y,
			}
			w1, w2 := derive_weights(
				coord_to_vertex(p),
				coord_to_vertex(a),
				coord_to_vertex(b),
				coord_to_vertex(c),
			)
			if !inside_triangle(w1, w2) {continue}

			w0 := 1 - w1 - w2
			z := (w0 * va.z) + (w1 * vb.z) + (w2 * vc.z)
			gray := u8(normalize(bnd, z) * 255)

			idx := (y * i32(Width)) + x
			if idx < 0 || idx >= i32(len(z_buf)) {continue}

			prev := z_buf[idx]
			if prev == 0 || z >= prev {
				z_buf[idx] = z
				set_pixel(p.x, p.y, buf, rgb)
				set_pixel(p.x, p.y, depth, [3]u8{gray, gray, gray})
			}
		}
	}
}

compose_matrices :: proc(m1: [9]f64, m2: [9]f64) -> [9]f64 {
	a, b, c, d, e, f, g, h, i := m1[0], m1[1], m1[2], m1[3], m1[4], m1[5], m1[6], m1[7], m1[8]
	j, k, l, m, n, o, p, q, r := m2[0], m2[1], m2[2], m2[3], m2[4], m2[5], m2[6], m2[7], m2[8]
	return [9]f64 {
		(a * j) + (b * m) + (c * p),
		(a * k) + (b * n) + (c * q),
		(a * l) + (b * o) + (c * r),
		(d * j) + (e * m) + (f * p),
		(d * k) + (e * n) + (f * q),
		(d * l) + (e * o) + (f * r),
		(g * j) + (h * m) + (i * p),
		(g * k) + (h * n) + (i * q),
		(g * l) + (h * o) + (i * r),
	}
}

// 1 0 0
// 0 1 0
// 0 0 1

identity_matrix :: proc() -> [9]f64 {
	return [9]f64{1, 0, 0, 0, 1, 0, 0, 0, 1}
}

rotation_matrix :: proc(theta: f64, axis: Axis) -> [9]f64 {
	switch axis {
	case Axis.X:
		return [9]f64 {
			1,
			0,
			0,
			0,
			math.cos_f64(theta),
			-math.sin_f64(theta),
			0,
			math.sin_f64(theta),
			math.cos_f64(theta),
		}
	case Axis.Y:
		return [9]f64 {
			math.cos_f64(theta),
			0,
			math.sin_f64(theta),
			0,
			1,
			0,
			-math.sin_f64(theta),
			0,
			math.cos_f64(theta),
		}
	case Axis.Z:
		return [9]f64 {
			math.cos_f64(theta),
			-math.sin_f64(theta),
			0,
			math.sin_f64(theta),
			math.cos_f64(theta),
			0,
			0,
			0,
			1,
		}
	}
	return identity_matrix()
}

transform :: proc(m: [9]f64, v: Vertex) -> Vertex {
	i, j, k := 0, 1, 2
	return Vertex {
		x = (v.x * m[i]) + (v.y * m[j]) + (v.z * m[k]),
		y = (v.x * m[i + 3]) + (v.y * m[j + 3]) + (v.z * m[k + 3]),
		z = (v.x * m[i + 6]) + (v.y * m[j + 6]) + (v.z * m[k + 6]),
	}
}

rotate :: proc(v: Vertex, axis: Axis, theta: f64) -> Vertex {
	switch axis {
	case Axis.X:
		return Vertex {
			x = v.x,
			y = v.y * math.cos_f64(theta) - v.z * math.sin_f64(theta),
			z = v.y * math.sin_f64(theta) + v.z * math.cos_f64(theta),
		}
	case Axis.Y:
		return Vertex {
			x = v.x * math.cos_f64(theta) + v.z * math.sin_f64(theta),
			y = v.y,
			z = -v.x * math.sin_f64(theta) + v.z * math.cos_f64(theta),
		}
	case Axis.Z:
		return Vertex {
			x = v.x * math.cos_f64(theta) - v.y * math.sin_f64(theta),
			y = v.x * math.sin_f64(theta) + v.y * math.cos_f64(theta),
			z = v.z,
		}
	}
	return Vertex{}
}

// NOTE: Sebastian Lague's epic video -> https://www.youtube.com/watch?v=HYAgJN3x4GA
// P = A + w1(B-A) + w2(C-A)

ensure_unique_apex :: proc(a, b, c: ^Coord) {
	if a.y == b.y {swap(a, c)} else if a.y == c.y {swap(a, b)}
}

inside_triangle :: proc(w1, w2: f64) -> bool {
	if w1 < 0 || w2 < 0 {return false}
	return w1 + w2 <= 1
}

derive_weights :: proc(p, a, b, c: Vertex) -> (f64, f64) {
	w1 := (a.x * (c.y - a.y)) + (p.y - a.y) * (c.x - a.x) - p.x * (c.y - a.y)
	w1 /= (b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y)
	w2 := p.y - a.y - w1 * (b.y - a.y)
	w2 /= c.y - a.y
	return w1, w2
}

triangle_area :: proc(a, b, c: Vertex) -> f64 {
	return math.abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
}

bounds :: proc(a, b, c: Coord) -> (Coord, Coord) {
	return Coord {
		x = min(a.x, b.x, c.x),
		y = min(a.y, b.y, c.y),
	}, Coord{x = max(a.x, b.x, c.x), y = max(a.y, b.y, c.y)}
}

normalize :: proc(bounds: [2]f64, n: f64) -> f64 {
	min, max := bounds[0], bounds[1]
	return (n - min) / (max - min)
}

z_bounds :: proc(vertices: [dynamic]Vertex) -> [2]f64 {
	min: f64 = math.F64_MAX
	max: f64 = -math.F64_MAX

	for v in vertices {
		if v.z < min {min = v.z}
		if v.z > max {max = v.z}
	}
	return [2]f64{min, max}
}

scanline_rasturize :: proc(triangle: Triangle, vertices: [dynamic]Vertex, buf: []u8) {
	points := []Coord {
		screen(vertices[triangle[0]]),
		screen(vertices[triangle[1]]),
		screen(vertices[triangle[2]]),
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
