Shader "Unlit/SSRPreviewShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma enable_d3d11_debug_symbols

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#define MAX_TRACE_DIS 50
			#define MAX_IT_COUNT 50         
			#define EPSION 0.1

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float4 vsRay : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);

			TEXTURE2D(_CameraDepthTexture);
			SAMPLER(sampler_CameraDepthTexture);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;

				float4 cameraRay = float4(v.uv.xy * 2.0 - 1.0, 1, 1.0);
				cameraRay = mul(unity_CameraInvProjection, cameraRay);
				o.vsRay = cameraRay / cameraRay.w;
                return o;
            }

			float2 PosToUV(float3 vpos)
			{
				float4 proj_pos = mul(unity_CameraProjection, float4(vpos, 1));
				float3 screenPos = proj_pos.xyz / proj_pos.w;
				return float2(screenPos.x, screenPos.y) * 0.5 + 0.5;
			}

			float compareWithDepth(float3 vpos, out bool isInside)
			{
				float2 uv = PosToUV(vpos);
				float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
				depth = LinearEyeDepth(depth, _ZBufferParams);
				isInside = uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
				return vpos.z + depth;
			}

			bool rayTrace(float3 o, float3 r, out float3 hitp)
			{
				float3 start = o;
				float3 end = o;
				float stepSize = 0.15;//MAX_TRACE_DIS / MAX_IT_COUNT;

				UNITY_LOOP
				for (int i = 1; i <= MAX_IT_COUNT; ++i)
				{
					end = o + r * stepSize * i;
					if (length(end - start) > MAX_TRACE_DIS)
						return false;

					bool isInside = true;
					float diff = compareWithDepth(end, isInside);
					if (isInside)
					{
						if (abs(diff) < 0.09)
						{
							hitp = end;
							return true;
						}
					}
					else
					{
						return false;
					}
				}
				return false;
			}

            float4 frag (v2f i) : SV_Target
            {
				//return float4(i.vsRay);
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
				depth = Linear01Depth(depth, _ZBufferParams);
			
				float3 wsNormal = float3(0,1,0);    //世界坐标系下的法线
				float3 vsNormal = (TransformWorldToViewDir(wsNormal));    //将转换到view space

				float3 vsRayOrigin = i.vsRay * depth;
				float3 reflectionDir = normalize(reflect(vsRayOrigin, vsNormal));

				float3 hitp = 0;
				float4 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv);
				if (rayTrace(vsRayOrigin, reflectionDir, hitp))
				{
					float2 tuv = PosToUV(hitp);
					float3 hitCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, tuv).xyz;
					col += float4(hitCol, 1);
				}

				return col;
            }
            ENDHLSL
        }
    }
}
