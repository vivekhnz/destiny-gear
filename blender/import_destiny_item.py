import bpy
import bmesh

def convert_to_tri_list(tri_strip):
    tri_list = [(tri_strip[0], tri_strip[2], tri_strip[1])]
    for i in range(1, len(tri_strip) - 2):
        if (i % 2 == 0):
            tri_list.append((tri_strip[i], tri_strip[i+2], tri_strip[i+1]))
        else:
            tri_list.append((tri_strip[i], tri_strip[i+1], tri_strip[i+2]))
    return tri_list


verts = [
    (0,0,0),
    (0,1,0),
    (1,0,0),
    (1,1,0),
    (2,0,0),
    (2,1,0),
    (3,0,0),
    (3,1,0),
    (0,0,1),
    (0,1,1),
    (1,0,1),
    (1,1,1),
    (2,0,1),
    (2,1,1),
    (3,0,1),
    (3,1,1)
]

tri_strip = [0,1,2,3,4,5,6,7]
indices = convert_to_tri_list(tri_strip)

mesh = bpy.data.meshes.new("MyMesh")
obj = bpy.data.objects.new("MyObject", mesh)

scene = bpy.context.scene
scene.objects.link(obj)
scene.objects.active = obj

mesh = bpy.context.object.data
bm = bmesh.new()

for v in verts:
    bm.verts.new(v)

bm.verts.ensure_lookup_table()
for i in indices:
    face = (bm.verts[i[0]], bm.verts[i[1]], bm.verts[i[2]])
    bm.faces.new(face)

bm.to_mesh(mesh)
bm.free()

bpy.ops.object.mode_set(mode='EDIT')
for v in bmesh.from_edit_mesh(mesh).verts:
    v.select = True
bpy.ops.mesh.delete_loose()
bpy.ops.object.mode_set(mode='OBJECT')