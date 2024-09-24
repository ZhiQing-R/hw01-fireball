#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

uniform float u_Time;

uniform float u_Freq;

uniform float u_Speed;

uniform float u_VoronoiScale;

uniform float u_Detail;

uniform vec4 u_InnerCol;

uniform vec4 u_OuterCol;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

// noise function reference: https://www.shadertoy.com/view/4sc3z2
#define MOD3 vec3(.1031,.11369,.13787)
vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * MOD3);
    p3 += dot(p3, p3.yxz+19.19);
    return -1.0 + 2.0 * fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float simplex(vec3 p)
{
    const float K1 = 0.333333333;
    const float K2 = 0.166666667;
    
    vec3 i = floor(p + (p.x + p.y + p.z) * K1);
    vec3 d0 = p - (i - (i.x + i.y + i.z) * K2);
    
    vec3 e = step(vec3(0.0), d0 - d0.yzx);
	vec3 i1 = e * (1.0 - e.zxy);
	vec3 i2 = 1.0 - e.zxy * (1.0 - e);
    
    vec3 d1 = d0 - (i1 - 1.0 * K2);
    vec3 d2 = d0 - (i2 - 2.0 * K2);
    vec3 d3 = d0 - (1.0 - 3.0 * K2);
    
    vec4 h = max(0.6 - vec4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
    vec4 n = h * h * h * h * vec4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));
    
    return dot(vec4(31.316), n);
}

float fbm(vec3 p)
{
    float f = 0.f;
    f += 1.f * simplex(p); p = 2.1f * p;
    f += 0.3f * simplex(p); p = 2.2f * p;
	f += 0.1f * simplex(p); p = 2.3f * p;
    return f / 1.4f;
}

vec2 hash2( vec2 p )
{
	return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

vec2 voronoi( in vec2 x )
{
    vec2 p = floor(x);
    vec2  f = fract(x);

    vec2 res = vec2(8.f);
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        vec2 b = vec2(i, j);
        vec2 r = vec2(b) - f + hash2(p+b);
        float d = dot( r, r );

        if( d < res.x )
        {
            res.y = res.x;
            res.x = d;
        }
        else if( d < res.y )
        {
            res.y = d;
        }
    }

    return sqrt( res );
}

void main()
{
    // Material base color (before shading)
        float alpha = mix(1.f, 0.5f, fs_Pos.y - 0.1f);
        vec4 diffuseColor = u_Color;
        vec3 red = u_InnerCol.xyz;
        vec3 yellow = u_OuterCol.xyz;

        float freq = 0.8f;
        vec3 timeOffset = u_Speed * vec3(0.003f * u_Time);
        float height = max(fbm(freq * fs_Pos.xyz + timeOffset), fbm(freq * (fs_Pos.xyz + vec3(13.41, 6423.42, 23754.4)) + timeOffset));
        height = 0.3f + pow(2.f * height + 0.2f, 2.f) / 2.f;
        float offset = 2.f * max(fs_Nor.y, 0.f) * height;


        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        diffuseTerm = max(diffuseTerm, 0.f);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        //fs_Nor = normalize(fs_Nor);
        float vScale = 4.f * u_VoronoiScale;
        vec2 noise = voronoi(vScale * fs_Pos.xz * cos(fs_Pos.y) + u_Time * 0.003f);
        float details = fbm(u_Detail * 2.f * fs_Pos.xyz + vec3(0.002f * u_Time));

        float dis = noise.y - noise.x;
        dis = 1.2f - smoothstep(0.f, 0.24f, dis);
        lightIntensity = mix(1.f, dis, max(-fs_Nor.y, 0.f));
        vec3 color = mix(red, yellow, max(abs(offset), dis * max(-fs_Nor.y, 0.f)));
        color = mix(color, yellow, details);

        // Compute final shaded color
        out_Col = vec4(color * lightIntensity, alpha);
}
