#include "map_dat.h"

#include <stdio.h>
#include <stdlib.h>

struct dat_file
{
    unsigned char number[2];
    unsigned char _unknown0[4];
    unsigned char ncols[2];
    unsigned char nrows[2];
    unsigned char _unknown1[4];
    unsigned char width[2];
    unsigned char height[2];
    unsigned char _unknown2[32];
    unsigned char easting[2];
    unsigned char northing[2];
    unsigned char version[2];
    unsigned char name[8];
    struct
    {
        union {
            struct
            {
                unsigned char _bit0 : 1;
                unsigned char has_los_block : 1;
                unsigned char _bit2 : 1;
                unsigned char has_elevation : 1;
                unsigned char _bit4 : 1;
                unsigned char has_road : 1;
                unsigned char has_woods : 1;
                unsigned char has_town : 1;
            } flags_bitset;
            unsigned char flags_byte;
        };
        unsigned char type;
    } terrains[0];
};

static struct tac_map *construct_map(const struct dat_file *dat)
{
    struct tac_map *m;
    int c, r;

    m = tac_map_create(*(short *) dat->width, *(short *) dat->height);

    /*
   * Convert and set the terrain values: 100x times more size for our model!
   * For every col, row of the .dat terrain we fill a 10x10 point square.
   */
    for (r = 0; r < *(short *) dat->nrows; ++r) {
        for (c = 0; c < *(short *) dat->ncols; ++c) {
            struct tac_terrain ter = {0};
            size_t index;
            int x, y;

            index = r * *(short *) dat->ncols + c;

            // convert base terrain type
            switch (dat->terrains[index].type) {
            case 0x00:
                ter.type = TAC_TERRAIN_TYPE_CLEAR;
                break;
            case 0x01:
                ter.type = TAC_TERRAIN_TYPE_NOGO_WHEELED;
                break;
            case 0x02:
                ter.type = TAC_TERRAIN_TYPE_NOGO_VEHICLES;
                break;
            case 0x04:
                ter.type = TAC_TERRAIN_TYPE_NOGO_EVERYONE;
                break;
            case 0x08:
                ter.type = TAC_TERRAIN_TYPE_ROUGH1;
                break;
            case 0x10:
                ter.type = TAC_TERRAIN_TYPE_ROUGH2;
                break;
            case 0x18:
                ter.type = TAC_TERRAIN_TYPE_ROUGH3;
                break;
            case 0x20:
                ter.type = TAC_TERRAIN_TYPE_ROUGH4;
                break;
            case 0x30:
                ter.type = TAC_TERRAIN_TYPE_WATER;
                break;
            default:
                printf("%s: spurious .dat terrain type: 0x%x\n",
                       __FUNCTION__,
                       dat->terrains[index].type);
                ter.type = TAC_TERRAIN_TYPE_CLEAR;
                break;
            }

            // convert any terrain flags
            ter.flags.has_los_block = dat->terrains[index]
                                          .flags_bitset.has_los_block;
            ter.flags.has_elevation = dat->terrains[index]
                                          .flags_bitset.has_elevation;
            ter.flags.has_road = dat->terrains[index].flags_bitset.has_road;
            ter.flags.has_woods = dat->terrains[index].flags_bitset.has_woods;
            ter.flags.has_town = dat->terrains[index].flags_bitset.has_town;

            // fill the appropriate 10x10 region with the given terrain
            for (y = 0; y < 10; ++y) {
                for (x = 0; x < 10; ++x) {
                    int ptx, pty;
                    int ret;

                    ptx = (c * 10) + x;
                    pty = (r * 10) + y;
                    if (ptx >= *(short *) dat->width
                        || pty >= *(short *) dat->height) {
                        // cull cases when (10 * .dat ncols/nrows) is bigger than the .dat
                        // width/height in pixels, like Map001c.
                        continue;
                    } else {
                        ret = tac_map_set_terrain(m, ptx, pty, ter);
                        if (ret) {
                            printf("%s: tac_map_set_terrain(m, %d, %d, ter) "
                                   "failed\n",
                                   __FUNCTION__,
                                   (c * 10) + x,
                                   (r * 10) + y);
                        }
                    }
                }
            }
        }
    }

    return m;
}

struct tac_map *tac_map_create_from_dat(const char *path)
{
    FILE *fp;
    size_t n;
    size_t filesize;
    struct dat_file *datmem;

    fp = fopen(path, "r");
    if (!fp) {
        return NULL;
    }

    fseek(fp, 0, SEEK_END);
    filesize = ftell(fp);
    rewind(fp);
    printf("%s: assuming file size %zu bytes\n", __FUNCTION__, filesize);

    datmem = calloc(1, filesize);

    n = fread(datmem, filesize, 1, fp);
    fclose(fp);
    if (n != 1) {
        printf("%s: read error\n", __FUNCTION__);
        return NULL;
    } else {
        printf(
            "%s: fetched contents into memory: %d x %d points, %d columns x %d "
            "rows, easting %d, northing %d, version %d, string '%s'\n",
            __FUNCTION__,
            *(short *) datmem->width,
            *(short *) datmem->height,
            *(short *) datmem->ncols,
            *(short *) datmem->nrows,
            *(short *) datmem->easting,
            *(short *) datmem->northing,
            *(short *) datmem->version,
            datmem->name);
        return construct_map(datmem);
    }
}
