shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint:source_color=vec4(0.25,0.35,0.13,1);
uniform float sway=0.08;
varying float height;
void vertex(){height=UV.y;VERTEX.x+=sin(TIME*1.7+NODE_POSITION_WORLD.x*0.8+NODE_POSITION_WORLD.z)*sway*UV.y;}
void fragment(){ALBEDO=tint.rgb*mix(0.55,1.25,height);ROUGHNESS=0.92;}
