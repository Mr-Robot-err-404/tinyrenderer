package main

import "core:math"

compose :: proc(m1: []f64, m2: []f64, size: int, result: []f64) {
	if len(m1) != len(m2) {panic("matrices have different sizes in composition")}

	for i := 0; i < len(m1); i += size {
		for offset := 0; offset < size; offset += 1 {
			sum: f64 = 0
			for n := 0; n < size; n += 1 {
				idx := (size * n) + offset
				sum += m1[i + n] * m2[idx]
			}
			result[i + offset] = sum
		}
	}
}

transform_matrix :: proc(m: []f64, v: []f64, size: int, result: []f64) {
	for offset := 0; offset < size; offset += 1 {
		sum: f64 = 0
		for n := 0; n < size; n += 1 {
			i := offset * size
			sum += m[i + n] * v[n]
		}
		result[offset] = sum
	}
}

divide :: proc(a: Vertex, n: f64) -> Vertex {
	return Vertex{x = a.x / n, y = a.y / n, z = a.z / n}
}

diff :: proc(a: Vertex, b: Vertex) -> Vertex {
	return Vertex{a.x - b.x, a.y - b.y, a.z - b.z}
}

cross_product :: proc(a: Vertex, b: Vertex) -> Vertex {
	return Vertex {
		x = (a.y * b.z) - (a.z * b.y),
		y = (a.z * b.x) - (a.x * b.z),
		z = (a.x * b.y) - (a.y * b.x),
	}
}

magnitude :: proc(v: Vertex) -> f64 {
	return math.sqrt_f64(math.pow_f64(v.x, 2) + math.pow_f64(v.y, 2) + math.pow_f64(v.z, 2))
}


compose_3D :: proc(m1: [9]f64, m2: [9]f64) -> [9]f64 {
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

// cosθ -sinθ
// sinθ cosθ

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

transform :: proc(m: []f64, v: Vertex) -> Vertex {
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
