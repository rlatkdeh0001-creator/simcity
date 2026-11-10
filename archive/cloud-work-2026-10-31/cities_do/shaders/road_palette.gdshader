shader_type spatial;
render_mode unshaded, cull_back;
uniform bool allow_white_paint = true;
uniform bool allow_yellow_paint = true;
uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 asphalt : source_color = vec4(0.298039, 0.337255, 0.349020, 1.0);
uniform vec4 curb : source_color = vec4(0.658824, 0.705882, 0.713725, 1.0);
uniform vec4 white_paint : source_color = vec4(0.909804, 0.905882, 0.862745, 1.0);
uniform vec4 yellow_paint : source_color = vec4(0.894118, 0.741176, 0.372549, 1.0);
uniform vec4 road_axes[64];
uniform int axis_count = 0;
uniform float half_carriageway = 0.0;
uniform vec4 openings[8];
uniform int opening_count = 0;
varying vec3 world_position;
float line_distance(vec2 p, vec4 axis) {
    vec2 a=axis.xy; vec2 d=axis.zw-a;
    float t=clamp(dot(p-a,d)/max(dot(d,d),0.000001),0.0,1.0);
    return distance(p,a+d*t);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 tex=texture(road_texture,UV).rgb;
    bool yellow=tex.r>0.4 && tex.g>0.3 && tex.b<tex.r*0.6;
    // The pinned upstream trim sheet has a 64/255 grey asphalt background.
    float base=0.25;
    float white_weight=clamp(2.0*(min(tex.r,min(tex.g,tex.b))-base)/max(1.0-base,0.001),0.0,1.0);
    bool opening=false;
    float mouth_blend=0.0;
    for (int i=0; i<8; i++) {
        if (i>=opening_count) { break; }
        float gap=line_distance(world_position.xz,openings[i]);
        if (gap<2.5) { opening=true; }
        mouth_blend=max(mouth_blend,1.0-smoothstep(0.05,2.5,gap));
    }
    float lateral=0.0;
    if (axis_count>0) {
        lateral=1000000.0;
        for (int i=0; i<64; i++) {
            if (i>=axis_count) { break; }
            lateral=min(lateral,line_distance(world_position.xz,road_axes[i]));
        }
    }
    vec3 color=asphalt.rgb;
    if (axis_count>0 && lateral>half_carriageway) { color=mix(curb.rgb,asphalt.rgb,mouth_blend); }
    if (yellow && allow_yellow_paint) { color=yellow_paint.rgb; }
    else if (!opening && allow_white_paint) { color=mix(color,white_paint.rgb,white_weight); }
    ALBEDO=color;
}
