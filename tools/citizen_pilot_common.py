"""Shared camera/canvas/action contract for the original citizen pilot."""
import bpy,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
WIDTH,HEIGHT=64,96
PIXELS_PER_METRE=40
ANCHOR=(32,84)
DIRECTIONS={'S':0,'SE':45,'E':90,'NE':135,'N':180}
FRAMES={'idle':('Idle',1),'1':('Walk',1),'2':('Walk',5),'3':('Walk',9),'4':('Walk',13)}
PARTS=['body','hair','top','bottom']

def studio(scale=4):
 scene=bpy.context.scene
 for o in list(scene.objects):
  if o.type in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
 data=bpy.data.cameras.new('CitizenCamera');camera=bpy.data.objects.new('CitizenCamera',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=1.6;data.clip_start=.1;data.clip_end=100
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=False;scene.render.film_transparent=True;scene.render.resolution_x=WIDTH*scale;scene.render.resolution_y=HEIGHT*scale;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.fps=20
 world=bpy.data.worlds.new('CitizenNeutralWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(1,1,1,1);world.node_tree.nodes['Background'].inputs[1].default_value=.80;scene.world=world
 data=bpy.data.lights.new('CitizenKey','AREA');data.energy=250;data.shape='DISK';data.size=4;o=bpy.data.objects.new('CitizenKey',data);scene.collection.objects.link(o);o.location=(-3,-4,6);o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 return camera

def set_view(direction):
 scene=bpy.context.scene;cam=scene.camera;angle=math.radians(DIRECTIONS[direction]);target_z=(ANCHOR[1]-HEIGHT/2)/(PIXELS_PER_METRE*math.cos(math.pi/6));target=Vector((0,0,target_z));offset=Vector((10*math.sin(angle),-10*math.cos(angle),10*math.tan(math.pi/6)))
 cam.location=target+offset;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();bpy.context.view_layer.update()
 right=cam.rotation_euler.to_matrix()@Vector((1,0,0));a=world_to_camera_view(scene,cam,-right*.5);b=world_to_camera_view(scene,cam,right*.5);measured=(b.x-a.x)*WIDTH;cam.data.ortho_scale*=measured/PIXELS_PER_METRE;bpy.context.view_layer.update()
 foot=world_to_camera_view(scene,cam,Vector((0,0,0)));current=(1-foot.y)*HEIGHT;target.z+=(ANCHOR[1]-current)/(PIXELS_PER_METRE*math.cos(math.pi/6));cam.location=target+offset;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam['target_m']=list(target);bpy.context.view_layer.update()
 foot=world_to_camera_view(scene,cam,Vector((0,0,0)));a=world_to_camera_view(scene,cam,-right*.5);b=world_to_camera_view(scene,cam,right*.5)
 return dict(direction=direction,azimuth_deg=DIRECTIONS[direction],elevation_deg=30,foot_anchor_px=[foot.x*WIDTH,(1-foot.y)*HEIGHT],pixels_per_metre=(b.x-a.x)*WIDTH,ortho_scale=cam.data.ortho_scale)

def set_pose(frame):
 action,index=FRAMES[frame];rig=bpy.data.objects['CitizenRig'];rig.animation_data.action=bpy.data.actions[action];bpy.context.scene.frame_set(index);bpy.context.view_layer.update()
