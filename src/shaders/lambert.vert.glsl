#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;

uniform float u_Freq;

uniform float u_Speed;

uniform float u_VoronoiScale;

uniform float u_Detail;


in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.


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
	f += 0.2f * simplex(p); p = 2.3f * p;
    //f += 0.1f * simplex(p); p = 2.3f * p;
    //f += 0.1f * simplex(p); p = 2.4f * p;
    return f / 1.6f;
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
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation
    fs_Pos = vs_Pos;

    //vec4 newPos = vec4((0.8f * pow(sin(hash33(vs_Pos.xyz) + 0.01f * u_Time), vec3(8.f)) + 0.5f) * vs_Pos.xyz, 1.f);
    

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    float vScale = 4.f * u_VoronoiScale;
    vec2 noise = voronoi(vScale * fs_Pos.xz * cos(fs_Pos.y) + u_Time * 0.003f);
    float dis = fs_Nor.y < 0.f ? noise.y - noise.x : 0.f;
    //dis = 1.0f - smoothstep(0.f, 0.14f, dis);

    float freq = u_Freq;
    vec3 timeOffset = u_Speed * vec3(0.003f * u_Time);
    float height = max(fbm(freq * vs_Pos.xyz + timeOffset), fbm(freq * (vs_Pos.xyz + vec3(13.41, 6423.42, 23754.4)) + timeOffset));
    height = 0.3f + pow(2.f * height + 0.2f, 2.f) / 2.f;
    vec4 newPos = vs_Pos + 0.8f * pow(vs_Nor.y + 0.8f, 2.f) * height * vec4(0,1,0,0);
    newPos.y -= 1.f;
    newPos += fs_Nor * dis * 0.08f;
    //if ((dis < 0.5f) && (vs_Nor.y < 0.f)) newPos += vs_Nor * 0.1f;


    vec4 modelposition = u_Model * newPos;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
