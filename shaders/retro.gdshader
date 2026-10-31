shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
void fragment(){vec3 c=texture(screen_texture,SCREEN_UV).rgb;float vignette=1.0-smoothstep(0.25,0.83,distance(SCREEN_UV,vec2(0.5)))*0.16;COLOR=vec4(c*vignette,1.0);}
