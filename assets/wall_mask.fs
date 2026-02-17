#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Uniforms nuevos
uniform vec2 playerPos;      // Posición en pantalla (Coordenadas Raylib: Origen Arriba-Izquierda)
uniform float screenHeight;  // Altura de la ventana para invertir el eje Y
uniform float radius;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // 1. Obtenemos la coordenada del píxel actual
    vec2 pixelPos = gl_FragCoord.xy;
    
    // 2. CORRECCIÓN VITAL: Invertimos la Y para coincidir con Raylib
    // Si no hacemos esto, el círculo se dibuja "en espejo" verticalmente
    pixelPos.y = screenHeight - pixelPos.y;

    // 3. Calculamos distancia usando las coordenadas corregidas
    float dist = distance(pixelPos, playerPos);

    // 4. Lógica de transparencia
    if (dist < radius)
    {
        float alpha = smoothstep(0.0, radius, dist);
        texelColor.a *= max(alpha, 0.2); // 0.2 es la opacidad mínima
    }

    finalColor = texelColor * colDiffuse * fragColor;
}