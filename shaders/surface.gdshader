shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint: source_color = vec4(1.0);
uniform float metal = 0.0;
uniform float kind = 0.0;
varying vec3 world;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(world*7.0)*0.65+noise(world*34.0)*0.35;
 float pattern=1.0;
 if(kind>0.5 && kind<1.5){
  vec2 brick=vec2(world.x+world.z,world.y)*vec2(2.2,3.8);
  brick.x+=mod(floor(brick.y),2.0)*0.5;
  vec2 edge=abs(fract(brick)-0.5);
  pattern=mix(1.0,0.42,smoothstep(0.44,0.49,max(edge.x,edge.y)));
 }
 if(kind>1.5 && kind<2.5){pattern=0.82+0.18*sin(world.y*20.0+noise(world*vec3(1,0.3,1))*12.0);}
 if(kind>2.5){vec2 tile=vec2(world.x*3.0,world.z*4.5);tile.x+=mod(floor(tile.y),2.0)*0.5;pattern=0.72+0.28*smoothstep(0.03,0.13,min(fract(tile.x),fract(tile.y)));}
 ALBEDO=tint.rgb*(0.78+n*0.32)*pattern;
 ROUGHNESS=mix(0.86,0.28,metal)+n*0.08;METALLIC=metal;
 NORMAL_MAP=normalize(vec3((noise(world*18.0)-0.5)*0.18,(noise(world*18.0+3.0)-0.5)*0.18,1.0))*0.5+0.5;
}
