#define RED 0xFF0000FF
#define GREEN 0x00FF00FF
#define BLUE 0x0000FFFF

__kernel void transpose_naif (__global unsigned *in, __global unsigned *out)
{
    int x = get_global_id (0);
    int y = get_global_id (1);

    out [x * DIM + y] = in [y * DIM + x];
}



__kernel void transpose (__global unsigned *in, __global unsigned *out)
{
    __local unsigned tile [TILEX][TILEY+1];
    int x = get_global_id (0);
    int y = get_global_id (1);
    int xloc = get_local_id (0);
    int yloc = get_local_id (1);

    tile [xloc][yloc] = in [y * DIM + x];

    barrier (CLK_LOCAL_MEM_FENCE);

    out [(x - xloc + yloc) * DIM + y - yloc + xloc] = tile [yloc][xloc];
}



// NE PAS MODIFIER
static unsigned color_mean (unsigned c1, unsigned c2)
{
    uchar4 c;

    c.x = ((unsigned)(((uchar4 *) &c1)->x) + (unsigned)(((uchar4 *) &c2)->x)) / 2;
    c.y = ((unsigned)(((uchar4 *) &c1)->y) + (unsigned)(((uchar4 *) &c2)->y)) / 2;
    c.z = ((unsigned)(((uchar4 *) &c1)->z) + (unsigned)(((uchar4 *) &c2)->z)) / 2;
    c.w = ((unsigned)(((uchar4 *) &c1)->w) + (unsigned)(((uchar4 *) &c2)->w)) / 2;

    return (unsigned) c;
}

// NE PAS MODIFIER
static int4 color_to_int4 (unsigned c)
{
    uchar4 ci = *(uchar4 *) &c;
    return convert_int4 (ci);
}

// NE PAS MODIFIER
static unsigned int4_to_color (int4 i)
{
    return (unsigned) convert_uchar4 (i);
}



// NE PAS MODIFIER
static float4 color_scatter (unsigned c)
{
    uchar4 ci;

    ci.s0123 = (*((uchar4 *) &c)).s3210;
    return convert_float4 (ci) / (float4) 255;
}

// NE PAS MODIFIER: ce noyau est appelé lorsqu'une mise à jour de la
// texture de l'image affichée est requise
__kernel void update_texture (__global unsigned *cur, __write_only image2d_t tex)
{
    int y = get_global_id (1);
    int x = get_global_id (0);
    int2 pos = (int2)(x, y);
    unsigned c;

    c = cur [y * DIM + x];

    write_imagef (tex, pos, color_scatter (c));
}

__kernel void LIFEG_NAIF (__global unsigned *in, __global unsigned *out)
{
    int x = get_global_id (0);
    int y = get_global_id (1);

    if(y > 0 && y < DIM-1 && x > 0 && x < DIM-1){
        int alive = 0;

        alive += (in[y*DIM+(x+1)] != 0) ? 1 : 0;
        alive += (in[y*DIM+(x-1)] != 0) ? 1 : 0;
        alive += (in[(y+1)*DIM+x] != 0) ? 1 : 0;
        alive += (in[(y-1)*DIM+x] != 0) ? 1 : 0;
        alive += (in[(y+1)*DIM+(x+1)] != 0) ? 1 : 0;
        alive += (in[(y+1)*DIM+(x-1)] != 0) ? 1 : 0;
        alive += (in[(y-1)*DIM+(x+1)] != 0) ? 1 : 0;
        alive += (in[(y-1)*DIM+(x-1)] != 0) ? 1 : 0;

        

        if(in[y*DIM+x] != 0) {
            out[y*DIM+x] = (alive == 2 || alive == 3) ? BLUE : 0;
        } else {
            out[y*DIM+x] = (alive == 3) ? GREEN : 0;
        }
    }

}

    __kernel void LIFEG_OPTIM (__global unsigned *in, __global unsigned *out, __global unsigned* tiles, __global unsigned* next_tiles)
{
    int x = get_global_id (0);
    int y = get_global_id (1);

    unsigned int TILES_QTY = (DIM+TILEX-1)/TILEX;
    int xloctile = x/TILEX;
    int yloctile = y/TILEY;

    if(tiles[xloctile + TILES_QTY * yloctile] != 0) {
        //We calculate tile
        if(x > 0 && y > 0 && x < DIM-1 && y < DIM-1){
            //By default we say it's not anymore modified
            next_tiles[xloctile+TILES_QTY*yloctile] = 0;

            int alive = 0;

            //strange but there the for wasnt working anymore, probably problem with indexes
            //doing the brutal way ...
            alive += (in[y*DIM+(x+1)] != 0) ? 1 : 0;
            alive += (in[y*DIM+(x-1)] != 0) ? 1 : 0;
            alive += (in[(y+1)*DIM+x] != 0) ? 1 : 0;
            alive += (in[(y-1)*DIM+x] != 0) ? 1 : 0;
            alive += (in[(y+1)*DIM+(x+1)] != 0) ? 1 : 0;
            alive += (in[(y+1)*DIM+(x-1)] != 0) ? 1 : 0;
            alive += (in[(y-1)*DIM+(x+1)] != 0) ? 1 : 0;
            alive += (in[(y-1)*DIM+(x-1)] != 0) ? 1 : 0;

            if(in[y*DIM+x] != 0) {
                out[y*DIM+x] = (alive == 2 || alive == 3) ? BLUE : 0;
            } else {
                out[y*DIM+x] = (alive == 3) ? GREEN : 0;
            }

            if(in[y*DIM+x] != out[y*DIM+x]){
                next_tiles[xloctile+TILES_QTY*yloctile] = 1;

                //To verify if we do x-1 tiles
                if(xloctile > 0){
                    next_tiles[(xloctile-1)+TILES_QTY*yloctile] = 1;
                    //Same, verify in case of x-1 if we do y+1 and/or y-1
                    if(yloctile > 0)
                        next_tiles[(xloctile-1)+TILES_QTY*(yloctile-1)] = 1;
                    if(yloctile < TILES_QTY-1)
                        next_tiles[(xloctile-1)+TILES_QTY*(yloctile+1)] = 1;
                }
                //To verify if we do x+1 tiles
                if(xloctile < TILES_QTY-1){
                    next_tiles[(xloctile+1)+TILES_QTY*yloctile] = 1;
                    //same
                    if(yloctile > 0)
                        next_tiles[(xloctile+1)+TILES_QTY*(yloctile-1)] = 1;
                    if(yloctile < TILES_QTY-1)
                        next_tiles[(xloctile+1)+TILES_QTY*(yloctile+1)] = 1;
                }
                //finally, y +/- 1
                if(yloctile > 0)
                    next_tiles[xloctile+TILES_QTY*(yloctile-1)] = 1;
                if(yloctile < TILES_QTY -1)
                    next_tiles[xloctile+TILES_QTY*(yloctile+1)] = 1;
            }
        }
    }
}
