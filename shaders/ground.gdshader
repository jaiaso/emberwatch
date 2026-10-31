shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world.xz;float macro=n(p*0.18);float fine=n(p*24.0);float path=min(abs(p.x-p.y*0.3),abs(p.y+p.x*0.22));float road=1.0-smoothstep(1.3,2.7+n(p*1.8)*0.7,path);road=max(road,1.0-smoothstep(3.4,5.1,length(p)));vec3 grass=mix(vec3(0.16,0.23,0.09),vec3(0.31,0.36,0.16),macro);vec3 dirt=mix(vec3(0.30,0.25,0.17),vec3(0.43,0.36,0.24),n(p*1.4));ALBEDO=mix(grass,dirt,road)*(0.86+fine*0.22);ROUGHNESS=0.96;NORMAL_MAP=vec3(0.5+(n(p*12.0)-0.5)*0.16,0.5+(n(p*12.0+5.0)-0.5)*0.16,1.0);}
