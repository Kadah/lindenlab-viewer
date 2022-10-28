/**
 * @file class3/deferred/screenSpaceReflUtil.glsl
 *
 * $LicenseInfo:firstyear=2007&license=viewerlgpl$
 * Second Life Viewer Source Code
 * Copyright (C) 2007, Linden Research, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation;
 * version 2.1 of the License only.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Linden Research, Inc., 945 Battery Street, San Francisco, CA  94111  USA
 * $/LicenseInfo$
 */

uniform sampler2D depthMap;
uniform sampler2D normalMap;
uniform sampler2D sceneMap;
uniform vec2 screen_res;
uniform mat4 projection_matrix;
uniform float zNear;
uniform float zFar;

uniform mat4 inv_proj;
// Shamelessly taken from http://casual-effects.blogspot.com/2014/08/screen-space-ray-tracing.html
// Original paper: https://jcgt.org/published/0003/04/04/
// By Morgan McGuire and Michael Mara at Williams College 2014
// Released as open source under the BSD 2-Clause License
// http://opensource.org/licenses/BSD-2-Clause

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

vec4 getPositionWithDepth(vec2 pos_screen, float depth);
float linearDepth(float depth, float near, float far);
float getDepth(vec2 pos_screen);
float linearDepth01(float d, float znear, float zfar);

bool traceScreenSpaceRay1(vec3 csOrig, vec3 csDir, float zThickness, 
                            float stride, float jitter, const float maxSteps, float maxDistance,
                            out vec2 hitPixel, out vec3 hitPoint)
{

    // Clip to the near plane    
    float rayLength = ((csOrig.z + csDir.z * maxDistance) > -zNear) ?
        (-zNear - csOrig.z) / csDir.z : maxDistance;
    vec3 csEndPoint = csOrig + csDir * rayLength;

    // Project into homogeneous clip space
    vec4 H0 = projection_matrix * vec4(csOrig, 1.0);
    vec4 H1 = projection_matrix * vec4(csEndPoint, 1.0);
    float k0 = 1.0 / H0.w, k1 = 1.0 / H1.w;

    // The interpolated homogeneous version of the camera-space points  
    vec3 Q0 = csOrig * k0, Q1 = csEndPoint * k1;

    // Screen-space endpoints
    vec2 P0 = H0.xy * k0, P1 = H1.xy * k1;

    // If the line is degenerate, make it cover at least one pixel
    // to avoid handling zero-pixel extent as a special case later
    P1 += vec2((distanceSquared(P0, P1) < 0.0001) ? 0.01 : 0.0);
    vec2 delta = P1 - P0;

    // Permute so that the primary iteration is in x to collapse
    // all quadrant-specific DDA cases later
    bool permute = false;
    if (abs(delta.x) < abs(delta.y)) { 
        // This is a more-vertical line
        permute = true; delta = delta.yx; P0 = P0.yx; P1 = P1.yx; 
    }

    float stepDir = sign(delta.x);
    float invdx = stepDir / delta.x;

    // Track the derivatives of Q and k
    vec3  dQ = (Q1 - Q0) * invdx;
    float dk = (k1 - k0) * invdx;
    vec2  dP = vec2(stepDir, delta.y * invdx);

    float strideScalar = 1.0 - min(1.0, -csOrig.z / 100);
    float pixelStride = 1.0 + strideScalar * stride;

    // Scale derivatives by the desired pixel stride and then
    // offset the starting values by the jitter fraction
    dP *= pixelStride; dQ *= pixelStride; dk *= pixelStride;
    P0 += dP * jitter; Q0 += dQ * jitter; k0 += dk * jitter;
    
    vec2 oneDividedByScreenRes = 1 / screen_res;
    vec4 pqk = vec4( P0, Q0.z, k0);
    vec4 dPQK = vec4( dP, dQ.z, dk);
    bool intersect = false;
    float zA = 0.0, zB = 0.0, i = 0;
    for (i = 0; i < maxSteps && intersect == false; i++) {
        pqk += dPQK;

        zA = zB;

        zB = (dPQK.z * 0.5 + pqk.z) / (dPQK.w * 0.5 + pqk.w);
        if (zB > zA) {
            float t = zB;
            zB = zA;
            zA = t;
        }

        hitPixel = permute ? pqk.yx : pqk.xy;
        
        hitPixel *= oneDividedByScreenRes;

        float depth = linearDepth01(getDepth(hitPixel), zNear, zFar) * -zFar;
        intersect = zB <= depth;
    }

    if (pixelStride > 1 && intersect == true) {
        pqk -= dPQK;
        dPQK /= pixelStride;

        float originalStride = pixelStride * 0.5;
        float oStride = originalStride;

        zA = pqk.z / pqk.w;
        zB = zA;
        for (int j = 0; j < maxSteps; j++) {
            pqk += dPQK * oStride;

            zA = zB;
            zB = (dPQK.z * -0.5 + pqk.z) / (dPQK.w * -0.5 + pqk.w);

            if (zB > zA) {
                float t = zB;
                zB = zA;
                zA = t;
            }

            hitPixel = permute ? pqk.yx : pqk.xy;
                    hitPixel *= oneDividedByScreenRes;


            originalStride *= 0.5;

            float depth = linearDepth01(getDepth(hitPixel), zNear, zFar) * -zFar;
            stride = zB <= depth ? -originalStride : originalStride;
        }
    }

    Q0.xy += dQ.xy * i;
    Q0.z = pqk.z;
    hitPoint = Q0 / pqk.w;

    return intersect;
}
