#version 100
precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Uniforms
uniform vec2 playerPos;
uniform float screenHeight;
uniform float radius;

void main()
{
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    
    vec2 pixelPos = gl_FragCoord.xy;
    pixelPos.y = screenHeight - pixelPos.y;

    float dist = distance(pixelPos, playerPos);

    if (dist < radius)
    {
        float alpha = smoothstep(0.0, radius, dist);
        texelColor.a *= max(alpha, 0.2);
    }

    gl_FragColor = texelColor * colDiffuse * fragColor;
}
