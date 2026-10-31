shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
float h(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){float n=h(floor(VERTEX*12.0));VERTEX*=0.84+n*0.28;world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){float n=h(floor(world*22.0));float strata=sin(world.y*18.0+sin(world.x*2.0+world.z)*2.0);float moss=smoothstep(0.4,0.9,sin(world.x*1.8+world.z)*0.5+0.5);ALBEDO=mix(vec3(0.24,0.25,0.23),vec3(0.23,0.28,0.15),moss*0.35)*(0.85+n*0.25+strata*0.1);ROUGHNESS=0.96;NORMAL_MAP=vec3(0.5+(n-0.5)*0.3,0.5+strata*0.13,1.0);}
