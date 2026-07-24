package main

import "core:fmt"
import "core:os"
import "core:strings"

Args :: struct {
	step:          Step,
	asset:         string,
	out:           string,
	with_lighting: bool,
	with_specular: bool,
}

usage :: proc() {
	fmt.println("usage: tinyrenderer <stage> [--asset head|monster] [--light] [--specular]")
	fmt.println()
	fmt.println("stages:")
	fmt.println("  wireframe   line drawing over OBJ vertices")
	fmt.println("  flat        solid color, face normals, z-buffer, backface culling")
	fmt.println("  smooth      solid color, interpolated vertex normals")
	fmt.println("  texture     UV diffuse map + tangent-space normal map")
	fmt.println()
	fmt.println("flags:")
	fmt.println("  --asset     model to render: head or monster (default: monster)")
	fmt.println("  --light     enable diffuse lighting (ambient + dot product)")
	fmt.println("  --specular  add Phong specular highlight (from spec map), implies --light")
	os.exit(1)
}

parse_args :: proc() -> Args {
	raw := os.args[1:]
	if len(raw) == 0 {usage()}

	args := Args {
		asset = "monster",
	}

	for i := 0; i < len(raw); i += 1 {
		switch raw[i] {
		case "--light":
			args.with_lighting = true
		case "--specular":
			args.with_specular = true
			args.with_lighting = true
		case "--asset":
			if i + 1 >= len(raw) {
				fmt.println("--asset requires a value: head or monster")
				os.exit(1)
			}
			i += 1
			if raw[i] != "head" && raw[i] != "monster" {
				fmt.printf("unknown asset: %s\n", raw[i])
				os.exit(1)
			}
			args.asset = raw[i]
		}
	}

	switch raw[0] {
	case "wireframe":
		args.step = .Wireframe
	case "flat":
		args.step = .Rasturization
		normal_mode = .Flat
		color_mode = .Solid
	case "smooth":
		args.step = .Rasturization
		normal_mode = .Smooth
		color_mode = .Solid
	case "texture":
		args.step = .Rasturization
		normal_mode = .Map
		color_mode = .Diffuse
	case:
		fmt.printf("unknown stage: %s\n\n", raw[0])
		usage()
	}

	use_lighting = args.with_lighting
	use_specular = args.with_specular

	// build output name: renders/<asset>_<stage>[_light][_specular].tga
	parts := make([dynamic]string)
	append(&parts, "renders/", args.asset, "_", raw[0])
	if args.with_lighting && !args.with_specular {append(&parts, "_light")}
	if args.with_specular {append(&parts, "_specular")}
	append(&parts, ".tga")
	args.out = strings.concatenate(parts[:])

	return args
}
