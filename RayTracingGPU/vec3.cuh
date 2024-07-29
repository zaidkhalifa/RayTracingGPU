#ifndef VEC3_CUH
#define VEC3_CUH

#include <iostream>
#include "rtutil.cuh"

class vec3 {
  public:
    double e[3];

    __device__ __host__ vec3() : e{0,0,0} {}
    __device__ __host__ vec3(double e0, double e1, double e2) : e{e0, e1, e2} {}

    __device__ __host__ double x() const { return e[0]; }
    __device__ __host__ double y() const { return e[1]; }
    __device__ __host__ double z() const { return e[2]; }

    __device__ __host__ vec3 operator-() const { return vec3(-e[0], -e[1], -e[2]); }
    __device__ __host__ double operator[](int i) const { return e[i]; }
    __device__ __host__ double& operator[](int i) { return e[i]; }

    __device__ __host__ vec3& operator+=(const vec3& v) {
        e[0] += v.e[0];
        e[1] += v.e[1];
        e[2] += v.e[2];
        return *this;
    }

    __device__ __host__ vec3& operator*=(const vec3& v) {
        e[0] *= v.e[0];
        e[1] *= v.e[1];
        e[2] *= v.e[2];
        return *this;
    }

    __device__ __host__ vec3& operator*=(double t) {
        e[0] *= t;
        e[1] *= t;
        e[2] *= t;
        return *this;
    }

    __device__ __host__ vec3& operator/=(double t) {
        return *this *= 1/t;
    }

    __device__ __host__ double length() const {
        return sqrt(length_squared());
    }

    __device__ __host__ double length_squared() const {
        return e[0]*e[0] + e[1]*e[1] + e[2]*e[2];
    }

    __device__ __host__ bool near_zero() const {
        // Return true if the vector is close to zero in all dimensions.
        auto s = 1e-8;
        return (fabs(e[0]) < s) && (fabs(e[1]) < s) && (fabs(e[2]) < s);
    }
};

// point3 is just an alias for vec3, but useful for geometric clarity in the code.
using point3 = vec3;


// Vector Utility Functions

inline std::ostream& operator<<(std::ostream& out, const vec3& v) {
    return out << v.e[0] << ' ' << v.e[1] << ' ' << v.e[2];
}

inline __device__ __host__  vec3 operator+(const vec3& u, const vec3& v) {
    return vec3(u.e[0] + v.e[0], u.e[1] + v.e[1], u.e[2] + v.e[2]);
}

inline __device__ __host__  vec3 operator-(const vec3& u, const vec3& v) {
    return vec3(u.e[0] - v.e[0], u.e[1] - v.e[1], u.e[2] - v.e[2]);
}

inline __device__ __host__  vec3 operator*(const vec3& u, const vec3& v) {
    return vec3(u.e[0] * v.e[0], u.e[1] * v.e[1], u.e[2] * v.e[2]);
}

inline __device__ __host__  vec3 operator*(double t, const vec3& v) {
    return vec3(t*v.e[0], t*v.e[1], t*v.e[2]);
}

inline __device__ __host__  vec3 operator*(const vec3& v, double t) {
    return t * v;
}

inline __device__ __host__  vec3 operator/(const vec3& v, double t) {
    return (1/t) * v;
}

inline __device__ __host__  double dot(const vec3& u, const vec3& v) {
    return u.e[0] * v.e[0]
         + u.e[1] * v.e[1]
         + u.e[2] * v.e[2];
}

inline __device__ __host__  vec3 cross(const vec3& u, const vec3& v) {
    return vec3(u.e[1] * v.e[2] - u.e[2] * v.e[1],
                u.e[2] * v.e[0] - u.e[0] * v.e[2],
                u.e[0] * v.e[1] - u.e[1] * v.e[0]);
}

inline __device__ __host__ vec3 unit_vector(const vec3& v) {
    return v / v.length();
}

inline __device__ vec3 reflect(const vec3& v, const vec3& n) {
    return v - 2*dot(v,n)*n;
}

inline vec3 refract(const vec3& uv, const vec3& n, double etai_over_etat) {
    auto cos_theta = fmin(dot(-uv, n), 1.0);
    vec3 r_out_perp =  etai_over_etat * (uv + cos_theta*n);
    vec3 r_out_parallel = -sqrt(fabs(1.0 - r_out_perp.length_squared())) * n;
    return r_out_perp + r_out_parallel;
}

#endif