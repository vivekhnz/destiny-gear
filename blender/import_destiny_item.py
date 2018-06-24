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


def read_some_data(context, filepath):
    f = open(filepath, 'rb')
    data = bytearray(f.read())
    f.close()

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

    print(len(data))

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
    filename_ext = ".tgx"

    filter_glob = StringProperty(
            default="*.tgx",
            options={'HIDDEN'},
            maxlen=255,  # Max internal buffer length, longer would be clamped.
            )

    def execute(self, context):
        return read_some_data(context, self.filepath)


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
