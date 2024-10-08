#include <cstdint>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include "rtutil.cuh"

#include "camera.cuh"
#include "hitbox.cuh"
#include "hitbox_list.cuh"
#include "material.cuh"
#include "sphere.cuh"

__global__ void render(double* img, camera** cam, hitbox_list** world, int image_width, curandState *states, double frac, uint8_t* imgu) 
{
    int x = blockIdx.x%image_width;
    int y = blockIdx.y;
    int pixel_count = gridDim.y*image_width;
    // int image_width = gridDim.x;
    // int y = threadIdx.x;
    int b_id = image_width*y + x;
    curandState localState = states[(b_id+threadIdx.x)%pixel_count];

    color pixel_color = (*cam)->render(*world, x, y, localState);

    states[(b_id+threadIdx.x)%pixel_count] = localState;

    int pos = y*image_width*3 + x*3;

    atomicAdd(&img[pos], frac*pixel_color.x());
    atomicAdd(&img[pos+1], frac*pixel_color.y());
    atomicAdd(&img[pos+2], frac*pixel_color.z());

    // img[pos] = frac*pixel_color.x();
    // img[pos+1] = frac*pixel_color.y();
    // img[pos+2] = frac*pixel_color.z();

    // write_color(imgu, img, y, x, image_width);
    // write_color(pixel_color, imgu, y, x, image_width);
}

__global__ void make_image(double* img, uint8_t* imgu, int image_width) 
{
    int x = blockIdx.x;
    int y = blockIdx.y; 

    write_color(imgu, img, y, x, image_width);
}

//Cuda functions

__global__ void setup_random(curandState *states)
{
    unsigned long long id = gridDim.x*blockIdx.y + blockIdx.x;
    curand_init(id, 0, 0, &(states[id]));
    
    // printf("\n(%d, %d):\n",blockIdx.y,blockIdx.x);
    // for(int i = 0; i < 5; i++)
    // {
    //     curandState st = states[id];
    //     printf("%lf\n",curand_uniform_double(&st));
    // }
}

__global__ void createCam(camera** cam, double aspectRatio, int imgWidth, double vFov, point3 lookfrom, point3 lookat, vec3 vup, double defocus_angle, double focus_dist)
{
    (*cam) = new camera();
    (*cam)->init(aspectRatio, imgWidth, vFov, lookfrom, lookat, vup, defocus_angle, focus_dist);
}

__global__ void initWorld(hitbox_list** world)
{
    (*world) = new hitbox_list();
}

__global__ void initMatLambertian(material** mat, color attenuation)
{
    (*mat) = new lambertian(attenuation);
}

__global__ void initMatMetal(material** mat, color attenuation, double fuzz = 0)
{
    (*mat) = new metal(attenuation, fuzz);
}

__global__ void initMatDielectric(material** mat, double index)
{
    (*mat) = new dielectric(index);
}

__global__ void addSphere(hitbox_list** world, point3 center, double radius, material** mat)
{
    (*world)->add(new sphere(center, radius, *mat));
}

__global__ void clean(camera** cam, hitbox_list** world)
{
    delete (*cam);
    (*world)->clear();
    delete (*world);
}

__global__ void delMat(material** mat)
{
    delete (*mat);
}

int main(void)
{
    init_constants();

    // World

    hitbox_list** world;
    cudaMalloc(&world, sizeof(hitbox_list*));
    initWorld<<<1,1>>>(world);

    // material **material_ground, **material_center, **material_left, **material_bubble, **material_right;
    // cudaMalloc(&material_ground, sizeof(material*));
    // cudaMalloc(&material_center, sizeof(material*));
    // cudaMalloc(&material_left, sizeof(material*));
    // cudaMalloc(&material_bubble, sizeof(material*));
    // cudaMalloc(&material_right, sizeof(material*));
    // initMatLambertian<<<1,1>>>(material_ground, color(0.8, 0.8, 0.0));
    // initMatLambertian<<<1,1>>>(material_center, color(0.1, 0.2, 0.5));
    // initMatDielectric<<<1,1>>>(material_left, 1.50);
    // initMatDielectric<<<1,1>>>(material_bubble, 1.00/1.50);
    // initMatMetal<<<1,1>>>(material_right, color(0.8, 0.6, 0.2), 1.0);

    // addSphere<<<1,1>>>(world, point3(0.0, -100.5, -1.0), 100.0, material_ground);
    // addSphere<<<1,1>>>(world, point3(0.0, 0.0, -1.2), 0.5, material_center);
    // addSphere<<<1,1>>>(world, point3(-1.0, 0.0, -1.0), 0.5, material_left);
    // addSphere<<<1,1>>>(world, point3(-1.0, 0.0, -1.0), 0.4, material_bubble);
    // addSphere<<<1,1>>>(world, point3(1.0, 0.0, -1.0), 0.5, material_right);

    material **ground_material;
    cudaMalloc(&ground_material, sizeof(material*));
    initMatLambertian<<<1,1>>>(ground_material, color(0.5, 0.5, 0.5));
    addSphere<<<1,1>>>(world, point3(0,-1000,0), 1000.0, ground_material);

    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            auto choose_mat = random_double_h();
            point3 center(a + 0.9*random_double_h(), 0.2, b + 0.9*random_double_h());

            if ((center - point3(4, 0.2, 0)).length() > 0.9) {
                material **sphere_material;
                cudaMalloc(&sphere_material, sizeof(material*));

                if (choose_mat < 0.8) 
                {
                    // diffuse
                    auto albedo = color_random() * color_random();
                    initMatLambertian<<<1,1>>>(sphere_material, albedo);
                    addSphere<<<1,1>>>(world, center, 0.2, sphere_material);
                } 
                else if (choose_mat < 0.95) 
                {
                    // metal
                    auto albedo = color_random(0.5, 1);
                    auto fuzz = random_double_h(0, 0.5);
                    initMatMetal<<<1,1>>>(sphere_material, albedo, fuzz);
                    addSphere<<<1,1>>>(world, center, 0.2, sphere_material);
                } 
                else {
                    // glass
                    initMatDielectric<<<1,1>>>(sphere_material, 1.5);
                    addSphere<<<1,1>>>(world, center, 0.2, sphere_material);
                }
            }
        }
    }

    material **material1;
    cudaMalloc(&material1, sizeof(material*));
    initMatDielectric<<<1,1>>>(material1, 1.5);
    addSphere<<<1,1>>>(world, point3(0, 1, 0), 1.0, material1);

    material **material2;
    cudaMalloc(&material2, sizeof(material*));
    initMatLambertian<<<1,1>>>(material2, color(0.4, 0.2, 0.1));
    addSphere<<<1,1>>>(world, point3(-4, 1, 0), 1.0, material2);

    material **material3;
    cudaMalloc(&material3, sizeof(material*));
    initMatMetal<<<1,1>>>(material3, color(0.7, 0.6, 0.5), 0.0);
    addSphere<<<1,1>>>(world, point3(4, 1, 0), 1.0, material3);

    // Image

    auto aspect_ratio = 16.0 / 9.0;
    unsigned int image_width = 2560;
    // unsigned int image_width = 4;

    // Calculate the image height, and ensure that it's at least 1.
    unsigned int image_height = max(1,int(image_width / aspect_ratio));

    // Camera

    double vFov     = 20.0;
    point3 lookfrom = point3(13,2,3);
    point3 lookat   = point3(0,0,0);
    vec3   vup      = vec3(0,1,0);

    double defocus_angle = 0.6;
    double focus_dist    = 10.0;

    camera** cam;
    cudaMalloc(&cam, sizeof(camera*));
    createCam<<<1,1>>>(cam, aspect_ratio, image_width, vFov, lookfrom, lookat, vup, defocus_angle, focus_dist);

    // Render

    unsigned int samples = 2048;
    // unsigned int divisions = samples/512;
    unsigned int divisions = (samples+511)/512 ;
    // unsigned int rem = samples-divisions*512;
    unsigned int samples_per_block = samples/divisions;
    double frac = 1.0/(samples_per_block*divisions);
    // frac = 1.0;

    std::cout << "Number of samples are "<< samples_per_block*divisions <<".\n";

    uint8_t* img;
    uint8_t* img_device;
    double* img_doubles;
    curandState* rand_states;


    img = (uint8_t*) malloc(sizeof(uint8_t)*image_width*image_height*3);
    cudaMalloc(&img_device, image_width*image_height*3);
    cudaMalloc(&img_doubles, image_width*image_height*3*sizeof(double));
    cudaMemset(img_doubles, 0.0, image_width*image_height*3);
    cudaMalloc(&rand_states, image_width*image_height*sizeof(curandState));

    setup_random<<<{image_width, image_height, 1}, 1>>>(rand_states);

    cudaDeviceSynchronize();

    // for (int i = 0; i < divisions; i++)
    // {
    //     render<<<{image_width, image_height, 1}, 512>>>(img_doubles, cam, world, image_width, rand_states, frac, img_device);
    // }
    // render<<<{image_width, image_height, 1}, rem>>>(img_doubles, cam, world, image_width, rand_states, frac, img_device);

    render<<<{image_width, image_height, divisions}, samples_per_block>>>(img_doubles, cam, world, image_width, rand_states, frac, img_device);

    cudaDeviceSynchronize();

    make_image<<<{image_width, image_height, 1}, 1>>>(img_doubles, img_device, image_width);

    cudaMemcpy(img, img_device, image_width*image_height*3, cudaMemcpyDeviceToHost);

    stbi_write_png("../../Image Samples/envTest.png", image_width, image_height, 3, img, image_width*3);

    clean<<<1,1>>>(cam, world);
    cudaFree(world);
    cudaFree(cam);
    free(img);
    cudaFree(img_device);
    cudaFree(img_doubles);
    cudaFree(rand_states);
    //TODO: delete materials
    
    return 0;
}