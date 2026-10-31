shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint:source_color=vec4(0.4,0.7,0.6,1);
void vertex(){VERTEX.z+=sin(TIME*3.0+UV.x*5.0+NODE_POSITION_WORLD.x)*0.12*UV.x;}
void fragment(){float weave=sin(UV.x*340.0)*sin(UV.y*240.0);ALBEDO=tint.rgb*(0.92+weave*0.07);ROUGHNESS=0.92;}
