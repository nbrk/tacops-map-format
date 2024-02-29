#pragma once

/*
 * Original TacOps(R) maps support.
 * 
 * Although the original .dat files use 10:1 pixel-to-terrain scale, we upscale
 * the map to be 1:1. This makes some "hard edges" on our high-definition maps.
 */
#include "map.h"

extern struct tac_map *tac_map_create_from_dat(const char *path);
