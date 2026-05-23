package main

import "core:fmt"

log_parts :: proc(parts: []string) {
	for s in parts {
		fmt.printf("%s:", s)
	}
	fmt.println()
}
