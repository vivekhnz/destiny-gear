import bpy
import bmesh
import struct


def convert_to_tri_list(tri_strip):
    tri_list = []
    for i in range(0, len(tri_strip) - 2):
        a = tri_strip[i]
        b = tri_strip[i+1]
        c = tri_strip[i+2]
        if (a == b or a == c or b == c):
            continue
        if (i % 2 == 0):
            tri_list.append((a, b, c))
        else:
            tri_list.append((a, c, b))
    return tri_list


def read_vertices(data):
    verts = []
    for i in range(0,len(data), 16):
        xBytes = data[i:i+4]
        yBytes = data[i+4:i+8]
        zBytes = data[i+8:i+12]
        x = struct.unpack('f', xBytes)
        y = struct.unpack('f', yBytes)
        z = struct.unpack('f', zBytes)
        verts.append((x[0],y[0],z[0]))
    return verts

def read_indices(data):
    indices = []
    for i in range(0,len(data), 2):
        indices.append(struct.unpack('H', data[i:i+2])[0])
    return indices

def create_mesh(verts, indices):
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
    # bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode='OBJECT')

def read_meshes(context, filepath):
    f = open(filepath, 'rb')
    data = bytearray(f.read())
    f.close()

    vertex_length = 14736
    indices_length = 5696

    verts = read_vertices(data[0:vertex_length])
    all_indices = data[vertex_length:vertex_length+indices_length]
    indices = convert_to_tri_list(read_indices(all_indices[2:686]))

    create_mesh(verts, indices)

    return {'FINISHED'}


# ImportHelper is a helper class, defines filename and
# invoke() function which calls the file selector.
from bpy_extras.io_utils import ImportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty
from bpy.types import Operator


class ImportDestinyItem(Operator, ImportHelper):
    """This appears in the tooltip of the operator and in the generated docs"""
    bl_idname = "import_data.destiny_item"  # important since its how bpy.ops.import_test.some_data is constructed
    bl_label = "Import Destiny Item"

    # ImportHelper mixin class uses this
    filename_ext = ".meshes"

    filter_glob = StringProperty(
            default="*.meshes",
            options={'HIDDEN'},
            maxlen=255,  # Max internal buffer length, longer would be clamped.
            )

    def execute(self, context):
        return read_meshes(context, self.filepath)


# Only needed if you want to add into a dynamic menu
def menu_func_import(self, context):
    self.layout.operator(ImportDestinyItem.bl_idname, text="Import Destiny Item")


def register():
    bpy.utils.register_class(ImportDestinyItem)
    bpy.types.INFO_MT_file_import.append(menu_func_import)


def unregister():
    bpy.utils.unregister_class(ImportDestinyItem)
    bpy.types.INFO_MT_file_import.remove(menu_func_import)


if __name__ == "__main__":
    register()

    # test call
    bpy.ops.import_data.destiny_item('INVOKE_DEFAULT')
