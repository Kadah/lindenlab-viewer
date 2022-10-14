/**
 * @file class3/deferred/screenSpaceReflPostF.glsl
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

#extension GL_ARB_texture_rectangle : enable

/*[EXTRA_CODE_HERE]*/

#ifdef DEFINE_GL_FRAGCOLOR
out vec4 frag_color;
#else
#define frag_color gl_FragColor
#endif

uniform vec2 screen_res;
uniform mat4 projection_matrix;
uniform mat4 inv_proj;
uniform float zNear;
uniform float zFar;

VARYING vec2 vary_fragcoord;

uniform sampler2DRect depthMap;
uniform sampler2DRect normalMap;
uniform sampler2DRect sceneMap;
uniform sampler2DRect diffuseRect;

vec3 getNorm(vec2 screenpos);
float getDepth(vec2 pos_screen);
float linearDepth(float d, float znear, float zfar);
vec4 getPositionWithDepth(vec2 pos_screen, float depth);
vec4 getPosition(vec2 pos_screen);
bool traceScreenSpaceRay1(vec3 csOrig, vec3 csDir, mat4 proj, float zThickness, 
                            float nearPlaneZ, float stride, float jitter, const float maxSteps, float maxDistance,
                            out vec2 hitPixel, out vec3 hitPoint);

void main() {
    vec2  tc = vary_fragcoord.xy * screen_res;
    vec3 pos = getPosition(tc).xyz;
    vec3 viewPos = normalize(pos);
    vec3 rayDirection = reflect(getNorm(tc), viewPos);
    vec2 hitpixel;
    vec3 hitpoint = viewPos;
    bool hit = traceScreenSpaceRay1(pos, rayDirection, projection_matrix,1, zNear, 1, 4, 20, 5, hitpixel, hitpoint);
    
    if (hit) {
        frag_color.rgb = vec3(hitpixel.x, hitpixel.y, 0);
    } else {
        frag_color.rgb = vec3(tc.x, tc.y, 0);
    }

    frag_color.a = 1.0;
}
