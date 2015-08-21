//@author: vvvv group
//@help: this is a very basic template. use it to start writing your own effects. if you want effects with lighting start from one of the GouraudXXXX or PhongXXXX effects
//@tags:
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;
float4x4 tWVP: WORLDVIEWPROJECTION;

float4 Color[2] : COLOR;
float3 RayOrigin <string uiname="Ray Origin";>;

float3 spherePos[2] <string uiname="Sphere Position";>;

float3 LDR<string uiname="Light Direction";> = 0.177;
static const float EPS = 0.0001;
static const int MAX_REF = 4;

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//texture transformation marked with semantic TEXTUREMATRIX to achieve symmetric transformations
float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;

//the data structure: "vertexshader to pixelshader"
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos   : POSITION;
    float2 TexCd : TEXCOORD0;
	float4 Pos1  : TEXCOORD1;
};

struct Ray
{
	float3 origin;
	float3 direction;
};

struct Sphere
{
	float radius;
	float3 position;
	float3 color;
};

struct Plane
{
	float3 position;
	float3 normal;
	float3 color;
};

struct Intersection
{
	float hit;
	float3 hitPoint;
	float3 normal;
	float3 color;
	float dist;
	float3 rayDir;
};

Sphere sphere[2];
Plane plane;

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------
vs2ps VS(
    float4 PosO  : POSITION,
    float4 TexCd : TEXCOORD0)
{
    //declare output struct
    vs2ps Out;

    //transform position
    Out.Pos = mul(PosO, tWVP);
	Out.Pos1 = Out.Pos;
    
    //transform texturecoordinates
    Out.TexCd = mul(TexCd, tTex);
	
    return Out;
}

void intersectInit(inout Intersection I){
    I.hit      = 0;
    I.hitPoint = 0.0;
    I.normal   = 0.0;
    I.color    = 0.0;
    I.dist = 1.0e+30;
    I.rayDir   = 0.0;
}

void intersectSphere(Ray R, Sphere S, inout Intersection I)
{
	float3 a = R.origin - S.position;
	float  b = dot(a, R.direction);
	float  c = dot(a, a) - (S.radius * S.radius);
	float  d = b * b - c;
	float  t = -b - sqrt(d);
	if (d > 0.0 && t > EPS && t < I.dist)
	{
		I.hitPoint = R.origin + R.direction * t;
		I.normal = normalize(I.hitPoint - S.position);
		float dd = clamp(dot(LDR, I.normal), 0.1, 1.0);
		I.color = S.color * dd;
		I.dist = t;
		I.hit++;
		I.rayDir = R.direction;
	}
}

void intersectPlane(Ray R, Plane P, inout Intersection I)
{
	float d = -dot(P.position, P.normal);
	float v = dot(R.direction, P.normal);
	float t = -(dot(R.origin, P.normal) + d) / v;
	if (t > EPS && t < I.dist)
	{
		I.hitPoint = R.origin + R.direction * t;
		I.normal = P.normal;
		float dd = clamp(dot(LDR, I.normal), 0.1, 1.0);
		float mm = fmod(I.hitPoint.x, 2.0);
		float nn = fmod(I.hitPoint.z, 2.0);

		if(
			((( mm  < -1.0) || ( 0.0 < mm && mm < 1.0)) && (( 0.0 < nn && nn < 1.0) || ( nn < -1.0))) ||
			(((1.0  <   mm) || (-1.0 < mm && mm <   0)) && ((-1.0 < nn && nn <   0) || (1.0 <   nn)))
		){
			dd *= 0.5;
		}
		
		float f = 1.0 - min(abs(I.hitPoint.z), 25.0) * 0.04;
		I.color = P.color * dd * f;
		I.dist = t;
		I.hit++;
		I.rayDir = R.direction;
	}
}

void intersectExec(Ray R, inout Intersection I){
    intersectSphere(R, sphere[0], I);
	intersectSphere(R, sphere[1], I);
    intersectPlane(R, plane, I);
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4 PS(vs2ps In): COLOR
{
	float4 p = In.Pos1;
	
	Ray ray;
	//ray.origin = float3(0.0, 0.0, 1.5);
	ray.origin = RayOrigin;
	ray.direction = normalize(float3(p.x, p.y, -1.0));
	
	// sphere init
	sphere[0].radius = 0.5;
//	sphere.position = float3(0.0, -0.5, 0.0);
	sphere[0].position = spherePos[0];
	sphere[0].color = Color[0].xyz;
	
	sphere[1].radius = 1;
	sphere[1].position = spherePos[1];
	sphere[1].color = Color[1].xyz;
	
	// plane init;
	plane.position = float3(0.0, -1.0, 0.0);
	plane.normal = float3(0.0, 1.0, 0.0);
	plane.color = float3(1.0, 1.0, 1.0);
	
	// intersection init
	Intersection its;
    intersectInit(its);
	
	// hit check
	float3 destColor = ray.direction.y;
	float3 tempColor = 1.0;
	Ray q;
	intersectExec(ray, its);
	if(its.hit > 0){
        destColor = its.color;
        tempColor *= its.color;
        for (int j = 1; j < MAX_REF; j++) {
            q.origin = its.hitPoint + its.normal * EPS;
            q.direction = reflect(its.rayDir, its.normal);
            intersectExec(q, its);
            if(its.hit > j){
                destColor += tempColor * its.color;
                tempColor *= its.color;
            }
        }
    }
	float4 col = float4(destColor, 1.0);
	
	return col;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TSimpleShader
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_1_1 VS();
        PixelShader  = compile ps_3_0 PS();
    }
}

technique TFixedFunction
{
    pass P0
    {
        //transforms
        WorldTransform[0]   = (tW);
        ViewTransform       = (tV);
        ProjectionTransform = (tP);

        //texturing
        Sampler[0] = (Samp);
        TextureTransform[0] = (tTex);
        TexCoordIndex[0] = 0;
        TextureTransformFlags[0] = COUNT2;
        //Wrap0 = U;  // useful when mesh is round like a sphere
        
        Lighting       = FALSE;

        //shaders
        VertexShader = NULL;
        PixelShader  = NULL;
    }
}
