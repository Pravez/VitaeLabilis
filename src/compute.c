
#include "compute.h"
#include "graphics.h"
#include "debug.h"
#include "ocl.h"

#include <stdbool.h>

#define RED 0xFF0000FF
#define GREEN 0x00FF00FF
#define BLUE 0x0000FFFF

unsigned version = 0;

void first_touch_v1 (void);
void first_touch_v2 (void);

unsigned compute_v0 (unsigned nb_iter);
unsigned compute_v1 (unsigned nb_iter);
unsigned compute_v2 (unsigned nb_iter);
unsigned compute_v3 (unsigned nb_iter);
unsigned compute_v4 (unsigned nb_iter);
unsigned compute_v5 (unsigned nb_iter);
unsigned compute_v6 (unsigned nb_iter);
unsigned compute_v7 (unsigned nb_iter);
unsigned compute_v8 (unsigned nb_iter);



void_func_t first_touch [] = {
    NULL,
    NULL,
    NULL,
    NULL,
};

int_func_t compute [] = {
    compute_v0, //Version sequentielle
    compute_v1, //Version OpenMP for de base
    compute_v2, //Version OpenMP for tuilee
    compute_v3, //Version OpenMP optimisee
    compute_v4,
    compute_v5,
    compute_v6,
    compute_v7,
    compute_v8,
};

char *version_name [] = {
    "Séquentielle",
    "OpenMP For basique",
    "OpenMP For Tuile",
    "OpenMP For Optimisee",
    "OpenMP Task tuilee",
    "OpenMP Task optimisee",
    "OpenCL basique",
    "OpenCL optimisee"
};

unsigned opencl_used [] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1
};

unsigned tranche;
unsigned int **tiles_tracker;

#define GRAIN 32

///////////////////////////// Version séquentielle simple

int verify_life(unsigned i, unsigned j) {
    int alive = 0;
    int start_x = i == 1 ? 0 : i-1;
    int start_y = j == 1 ? 0 : j-1;

    int end_x = start_x + 3 >= DIM-1 ? DIM-1 : start_x + 3;
    int end_y = start_y + 3 >= DIM-1 ? DIM-1 : start_y + 3;

    for(int x = start_x; x < end_x; x++) {
        for(int y = start_y; y < end_y; y++) {
            if((x != i || y != j) && cur_img(x, y) != 0) {
                alive+=1;
            }
        }
    }

    if(cur_img(i, j) != 0) {
        return (alive == 2 || alive == 3) ? BLUE : 0;
    } else {
        return (alive == 3) ? GREEN : 0;
    }
}


unsigned compute_v0 (unsigned nb_iter)
{

    for (unsigned it = 1; it <= nb_iter; it ++) {
        for (int i = 1; i < DIM-1; i++) {
            for (int j = 1; j < DIM-1; j++) {
                next_img (i, j) = verify_life(i, j);
            }
        }

        swap_images();
    }
    // retourne le nombre d'étapes nécessaires à la
    // stabilisation du calcul ou bien 0 si le calcul n'est pas
    // stabilisé au bout des nb_iter itérations
    return 0;
}


///////////////////////////// Version OpenMP de base

//Version OpenMP basique
void first_touch_v1 ()
{
    int i,j ;

    #pragma omp parallel for collapse(2)
    for(i=1; i<DIM-1 ; i++) {
        for(j=1; j < DIM-1 ; j ++)
            next_img (i, j) = verify_life (i, j);
    }
}

// Renvoie le nombre d'itérations effectuées avant stabilisation, ou 0
unsigned compute_v1(unsigned nb_iter)
{
    first_touch_v1();
    swap_images();
    return 0;
}

/////////////////////////////Version OpenMP tuilee
int pixel_handler (int x, int y)
{
    int alive = 0;

    for (int i = x-1; i <= x+1; i++) {
        for (int j = y-1; j <= y+1; j++) {
            if ((i != x || j != y) && cur_img (i,j) != 0) {
                alive += 1;
            }
        }
    }

    if(cur_img(x, y) != 0)
        return (alive == 2 || alive == 3) ? BLUE : 0;
    else
        return (alive == 3) ? GREEN : 0;
}

void tile_handler (int i, int j)
{
    int i_d = (i == 1) ? 1 : i * tranche;
    int j_d = (j == 1) ? 1 : j * tranche;
    int i_f = (i == GRAIN-1) ? DIM-1 : (i+1) * tranche;
    int j_f = (j == GRAIN-1) ? DIM-1 : (j+1) * tranche;

    for(int x = i_d; x < i_f; ++x) {
        for(int y = j_d; y < j_f; ++y) {
            next_img(x, y) = pixel_handler(x, y);
        }
    }
}

int launch_tile_handlers (void)
{
    tranche = DIM / GRAIN;

    #pragma omp parallel for collapse(2) schedule(static)
    for (int i=1; i < GRAIN; i++)
        for (int j=1; j < GRAIN; j++)
            tile_handler (i, j);

    return 0;
}

unsigned compute_v2(unsigned nb_iter) {
    launch_tile_handlers();
    swap_images();
    return 0;
}


///////////////////////////// Version OpenMP optimisée
//réduire le nombre de tuiles à calculer : calculer ou non les tuiles adjacentes suivant les calculs aux bords
// Renvoie le nombre d'itérations effectuées avant stabilisation, ou 0
int pixel_handler_optim (int x, int y)
{
    int alive = 0;
    int returned = 0;

    for (int i = x-1; i <= x+1; i++) {
        for (int j = y-1; j <= y+1; j++) {
            if ((i != x || j != y) && cur_img (i,j) != 0) {
                alive += 1;
            }
        }
    }

    if(cur_img(x, y) != 0) {
        returned = (alive == 2 || alive == 3) ? BLUE : 0;
    } else {
        returned = (alive == 3) ? GREEN : 0;
    }

    return returned;
}

int check_changed(int i, int j) {
    return ;
}

void tile_handler_optim (int i, int j)
{
    //If it changed
    if(tiles_tracker[i-1][j] || tiles_tracker[i][j-1] || tiles_tracker[i+1][j] || tiles_tracker[i][j+1]) {
        int i_d = (i == 1) ? 1 : i * tranche;
        int j_d = (j == 1) ? 1 : j * tranche;
        int i_f = (i == GRAIN-1) ? DIM-1 : (i+1) * tranche;
        int j_f = (j == GRAIN-1) ? DIM-1 : (j+1) * tranche;

        int value = 0;

        for(int x = i_d; x < i_f; ++x) {
            for(int y = j_d; y < j_f; ++y) {
                value = pixel_handler_optim(x, y);
                if(cur_img(x, y) != value && !tiles_tracker[i][j])
                    tiles_tracker[i][j] = 1;
                next_img(x, y) = value;
            }
        }
    }
}

int launch_tile_handlers_optim (void)
{
    tranche = DIM / GRAIN;

    //First we keep a trace of eventual changing of other tiles
    tiles_tracker = malloc(sizeof(unsigned int*)*(GRAIN+2));
    for(int i = 0; i < GRAIN+1; i++) {
        tiles_tracker[i] = malloc(sizeof(unsigned int)*(GRAIN+2));
        for(int j = 0; j < GRAIN; j++) {
            tiles_tracker[i][j] = i == 0 || j == 0 || i == GRAIN+1 || j == GRAIN+1 ? 1 : 0;
        }
    }

    #pragma omp parallel for collapse(2) schedule(static)
    for (int i=1; i < GRAIN; i++)
        for (int j=1; j < GRAIN; j++)
            tile_handler_optim (i, j);

    //We free allocated memory
    for(int i = 0; i < GRAIN; i++) {
        free(tiles_tracker[i]);
    }
    free(tiles_tracker);

    return 0;
}

unsigned compute_v3(unsigned nb_iter)
{
    launch_tile_handlers_optim();
    swap_images();
    return 0; // on ne s'arrête jamais
}


///////////////////////////// Version OpenCL

// Renvoie le nombre d'itérations effectuées avant stabilisation, ou 0
unsigned compute_v4 (unsigned nb_iter)
{
    return ocl_compute (nb_iter);
}

unsigned compute_v5(unsigned nb_iter)
{
    return 0; // on ne s'arrête jamais
}
unsigned compute_v6(unsigned nb_iter)
{
    return 0; // on ne s'arrête jamais
}
unsigned compute_v7(unsigned nb_iter)
{
    return 0; // on ne s'arrête jamais
}
unsigned compute_v8(unsigned nb_iter)
{
    return 0; // on ne s'arrête jamais
}