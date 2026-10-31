shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint:source_color=vec4(0.12,0.22,0.09,1);
varying vec3 pos;
float h(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){pos=VERTEX;float n=h(floor(VERTEX*16.0));VERTEX*=0.86+n*0.30;VERTEX.x+=sin(TIME*1.4+NODE_POSITION_WORLD.x+VERTEX.y*3.0)*0.025;}
void fragment(){float leaf=h(floor(pos*92.0));float needle=sin(pos.x*160.0+pos.z*92.0);ALBEDO=tint.rgb*(0.58+leaf*0.66+needle*0.12);ROUGHNESS=0.95;NORMAL_MAP=vec3(0.5+(leaf-0.5)*0.34,0.5+(needle)*0.12,1.0);}
