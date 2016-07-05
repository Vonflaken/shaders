Shader "Sprites/Specular"
{
	Properties
	{
		[PerRendererData] _MainTex("Sprite Texture", 2D) = "white" {}
		_NormalTex("Sprite Normal Texture", 2D) = "bump" {}
		[MaterialToggle] PixelSnap("Pixel snap", Float) = 0
		_SpecColor("Specular Material Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Float) = 10
	}

	SubShader
	{
		Cull Off
		ZWrite Off

		Pass
		{
	
		Blend One OneMinusSrcAlpha

		Tags
		{
			"Queue"					= "Transparent"
			"IgnoreProjector"		= "True"
			"RenderType"			= "Transparent"
			"PreviewType"			= "Plane"
			"CanUseSpriteAtlas"		= "True"
			"LightMode"				= "ForwardBase"
		}

		CGPROGRAM

		#pragma multi_compile_fwbase			
		#pragma multi_compile _ PIXELSNAP_ON
		#pragma vertex vert
		#pragma fragment frag

		#include "UnityCG.cginc"

		struct vertexInput
		{
			float4 vertex   : POSITION;
			float4 color    : COLOR;
			float2 texcoord : TEXCOORD0;
			float3 normal	: NORMAL;
		};

		struct vertexOutput
		{
			float4 vertex				: SV_POSITION;
			fixed4 color				: COLOR;
			float2 texcoord				: TEXCOORD0;
			float4 posWorld				: TEXCOORD1;
			float3 normalDir			: TEXCOORD2;
			float3 vertexLighting		: TEXCOORD3;
		};

		sampler2D		_NormalTex;
		float4			_SpecColor;
		float			_Shininess;
		float4			_LightColor0;
		sampler2D		_MainTex;
		sampler2D		_AlphaTex;
		float			_AlphaSplitEnabled;

		fixed4 SampleSpriteTexture(float2 uv)
		{
			fixed4 color = tex2D(_MainTex, uv);

#if UNITY_TEXTURE_ALPHASPLIT_ALLOWED
			if (_AlphaSplitEnabled)
				color.a = tex2D(_AlphaTex, uv).r;
#endif

			return color;
		}

		vertexOutput vert(vertexInput IN)
		{
			vertexOutput OUT;

			OUT.vertex = mul(UNITY_MATRIX_MVP, IN.vertex);
			OUT.texcoord = IN.texcoord;
			OUT.color = IN.color;
#ifdef PIXELSNAP_ON
			OUT.vertex = UnityPixelSnap(OUT.vertex);
#endif

			float4x4 modelMatrix = _Object2World;
			float4x4 modelMatrixInverse = _World2Object;

			OUT.posWorld = mul(modelMatrix, IN.vertex);
			OUT.normalDir = normalize(mul(float4(IN.normal, 0.0), modelMatrixInverse).xyz);
			OUT.vertex = mul(UNITY_MATRIX_MVP, IN.vertex);

			OUT.vertexLighting = float3(0.0, 0.0, 0.0);
#ifdef VERTEXLIGHT_ON
			for (int index = 0; index < 4; index++)
			{
				float4 lightPosition = float4(unity_4LightPosX0[index],
					unity_4LightPosY0[index],
					unity_4LightPosZ0[index], 1.0);

				float3 vertexToLightSource =
					lightPosition.xyz - OUT.posWorld.xyz;
				float3 lightDirection = normalize(vertexToLightSource);
				float squaredDistance = dot(vertexToLightSource, vertexToLightSource);
				float attenuation = 1.0 / (1.0 + unity_4LightAtten0[index] * squaredDistance);
				float3 diffuseReflection = attenuation
					* unity_LightColor[index].rgb
					* max(0.0, dot(OUT.normalDir, lightDirection));

				OUT.vertexLighting = OUT.vertexLighting + diffuseReflection;
			}
#endif
			return OUT;
		}

		float4 frag(vertexOutput IN) : SV_Target
		{
			fixed4 texColor = SampleSpriteTexture(IN.texcoord) * IN.color;
			texColor.rgb *= texColor.a;

			half3 worldNormal = UnityObjectToWorldNormal(UnpackNormal(tex2D(_NormalTex, IN.texcoord)));

			float3 normalDirection = normalize(IN.normalDir);
			float3 viewDirection = normalize(_WorldSpaceCameraPos - IN.posWorld.xyz);

			float3 lightDirection;
			float attenuation;
			if (0.0 == _WorldSpaceLightPos0.w)
			{
				attenuation = 1.0;
				lightDirection = normalize(_WorldSpaceLightPos0.xyz);
			}
			else
			{
				float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - IN.posWorld.xyz;
				float distance = length(vertexToLightSource);
				attenuation = 1.0 / distance;
				lightDirection = normalize(vertexToLightSource);
			}

			float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;

			float3 diffuseReflection =
				attenuation * _LightColor0.rgb
				* max(0.0, dot(normalDirection, lightDirection));

			float3 specularReflection;
			if (dot(normalDirection, lightDirection) < 0.0)
			{
				specularReflection = float3(0.0, 0.0, 0.0);
			}
			else
			{
				specularReflection = attenuation * _LightColor0.rgb
					* _SpecColor.rgb * pow(max(0.0, dot(
						reflect(-lightDirection, normalDirection),
						viewDirection)), _Shininess);
			}

			return float4(texColor.rgb * (IN.vertexLighting + ambientLighting
				+ diffuseReflection + specularReflection), texColor.a);
		}

		ENDCG
		}

		Pass
		{

		Tags
		{
			"Queue"					= "Transparent"
			"IgnoreProjector"		= "True"
			"RenderType"			= "Transparent"
			"PreviewType"			= "Plane"
			"CanUseSpriteAtlas"		= "True"
			"LightMode"				= "ForwardAdd"
		}

		Blend One One

		CGPROGRAM

		#pragma multi_compile _ PIXELSNAP_ON
		#pragma multi_compile_fwdadd
		#pragma vertex vert
		#pragma fragment frag

		#include "UnityCG.cginc"
		#include "AutoLight.cginc"

		struct vertexInput
		{
			float4 vertex			: POSITION;
			float4 color			: COLOR;
			float2 texcoord			: TEXCOORD0;
		};

		struct vertexOutput
		{
			float4 vertex			: SV_POSITION;
			fixed4 color			: COLOR;
			float2 texcoord			: TEXCOORD0;
			float4 posWorld			: TEXCOORD1;
			LIGHTING_COORDS(2, 3)
		};

		float4			_LightColor0;
		float4			_SpecColor;
		float			_Shininess;
		sampler2D		_MainTex;
		sampler2D		_NormalTex;
		sampler2D		_AlphaTex;
		float			_AlphaSplitEnabled;

		fixed4 SampleSpriteTexture(float2 uv)
		{
			fixed4 color = tex2D(_MainTex, uv);

#if UNITY_TEXTURE_ALPHASPLIT_ALLOWED
			if (_AlphaSplitEnabled)
				color.a = tex2D(_AlphaTex, uv).r;
#endif

			return color;
		}

		vertexOutput vert(vertexInput v)
		{
			vertexOutput OUT;

			float4x4 modelMatrix = _Object2World;
			float4x4 modelMatrixInverse = _World2Object;

			OUT.posWorld = mul(modelMatrix, v.vertex);
			OUT.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
			OUT.texcoord = v.texcoord;
			OUT.color = v.color;
			TRANSFER_VERTEX_TO_FRAGMENT(OUT);

			return OUT;
		}

		float4 frag(vertexOutput IN) : SV_Target
		{
			float3 normal = (tex2D(_NormalTex, IN.texcoord).xyz - 0.5f) * 2.0f;
			normal = mul(float4(normal, 1.0f), _World2Object).xyz;
			normal.z *= -1;
			normal = normalize(normal);

			float3 normalDirection = normal;

			float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - IN.posWorld.xyz);
			float3 lightDirection;
			float attenuation;

			if (0.0 == _WorldSpaceLightPos0.w)
			{
				attenuation = 1.0;
				lightDirection = normalize(_WorldSpaceLightPos0.xyz);
			}
			else
			{
				float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - IN.posWorld.xyz;
				float distance = length(vertexToLightSource);
				attenuation = LIGHT_ATTENUATION(IN);
				lightDirection = normalize(vertexToLightSource);
			}

			float3 diffuseReflection =
				attenuation * _LightColor0.rgb
				* max(0.0, dot(normalDirection, lightDirection));

			float3 specularReflection;
			if (dot(normalDirection, lightDirection) < 0.0)
			{
				specularReflection = float3(0.0, 0.0, 0.0);
			}
			else
			{
				specularReflection = attenuation * _LightColor0.rgb
					* _SpecColor.rgb * pow(max(0.0, dot(
						reflect(-lightDirection, normalDirection),
						viewDirection)), _Shininess);
			}

			float alpha = SampleSpriteTexture(IN.texcoord).a * IN.color.a;

			return float4((diffuseReflection
				+ specularReflection) * alpha, 1.0);
		}

		ENDCG
		}
	}
}
