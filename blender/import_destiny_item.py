import bpy
import bmesh
import io
import json
import os.path
import struct
from enum import IntEnum
from operator import itemgetter

SETTINGS_PATH = bpy.path.abspath('//destiny_item_settings.json')
DEFAULT_SETTINGS = {
    'texture_path': 'textures'
}

def read(f, fmt, size, n):
    if n == 1:
        return struct.unpack(fmt, bytearray(f.read(size)))[0]
    
    return struct.unpack(str(n) + fmt, bytearray(f.read(size * n)))

def read_int(f, n = 1):
    return read(f, 'i', 4, n)

def read_float(f, n = 1):
    return read(f, 'f', 4, n)

def read_short(f, n = 1):
    return read(f, 'h', 2, n)

def read_bool(f, n = 1):
    return read(f, '?', 1, n)

def read_byte(f, n = 1):
    array = bytearray(f.read(n))
    if n == 1:
        return array[0]
    return tuple(array)

def read_string(f):
    string_length = int.from_bytes(bytearray(f.read(1)), byteorder = 'little')
    return bytearray(f.read(string_length)).decode('utf-8')

def read_array(f, read_func):
    count = read_int(f)
    return [read_func(f) for i in range(count)]

def normalize(value, min_value, max_value):
    if (type(value) == tuple):
        return [normalize(v, min_value, max_value) for v in value]
    return (value - min_value) / (max_value - min_value)

def read_element_value(f, read_func, normalized, min_value, max_value):
    value = read_func(f)
    if normalized:
        value = normalize(value, min_value, max_value)
    return value

STREAM_TYPE_READERS = {
    # FLOAT2
    0: (lambda f, normalized:
        read_element_value(f, lambda f: read_float(f, 2), normalized, -(2**31), 2**31)
    ),
    # FLOAT4
    1: (lambda f, normalized:
        read_element_value(f, lambda f: read_float(f, 4), normalized, -(2**31), 2**31)
    ),
    # SHORT2
    2: (lambda f, normalized:
        read_element_value(f, lambda f: read_short(f, 2), normalized, -(2**15), 2**15)
    ),
    # SHORT4
    3: (lambda f, normalized:
        read_element_value(f, lambda f: read_short(f, 4), normalized, -(2**15), 2**15)
    ),
    # UBYTE4
    4: (lambda f, normalized:
        read_element_value(f, lambda f: read_byte(f, 4), normalized, 0, 2**8)
    )
}

STREAM_SEMANTIC_MODIFIERS = {
    # POSITION
    (0, 0): (lambda vertex, value: vertex.set_position(value)),
    # TEXCOORD
    (1, 0): (lambda vertex, value: vertex.set_uv(value)),
    # NORMAL
    (2, 0): (lambda vertex, value: vertex.set_normal(value))
}

class Vertex(object):
    def __init__(self):
        self.position = None
        self.uv = None
        self.normal = None
    
    def set_position(self, xyzw):
        self.position = (xyzw[0], xyzw[1], xyzw[2])
    
    def set_uv(self, uv):
        self.uv = (
            (uv[0] * 2) - 1,
            (uv[1] * 2) - 1
        )
    
    def set_normal(self, xyzw):
        self.normal = (
            (xyzw[0] * 2) - 1,
            (xyzw[1] * 2) - 1,
            (xyzw[2] * 2) - 1
        )

class StreamElement(object):
    def __init__(self, element_type, semantic, semantic_index, normalized):
        self.reader = STREAM_TYPE_READERS.get(element_type)
        if self.reader is None:
            raise NotImplementedError("No reader defined for element type " + str(element_type))

        self.modifier = STREAM_SEMANTIC_MODIFIERS.get((semantic, semantic_index))
        self.is_normalized = normalized
    
    def modify_vertex(self, f, vertex):
        value = self.reader(f, self.is_normalized)
        
        if self.modifier is not None:
            self.modifier(vertex, value)

class TextureSet(object):
    def __init__(self):
        self.diffuse = None
        self.normal = None
        self.gearstack = None

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

def read_element(f):
    return StreamElement(read_int(f), read_int(f), read_int(f), read_bool(f))

def fill_vertex(f, vertex, elements):
    for element in elements:
        element.modify_vertex(f, vertex)

def fill_vertices(f, vertices):
    element_count = read_int(f)
    elements = [read_element(f) for i in range(element_count)]

    for vertex in vertices:
        fill_vertex(f, vertex, elements)

def create_mesh(verts, indices, texcoord_scale, texcoord_offset):
    mesh = bpy.data.meshes.new("MyMesh")
    obj = bpy.data.objects.new("MyObject", mesh)

    scene = bpy.context.scene
    scene.objects.link(obj)
    scene.objects.active = obj

    mesh = bpy.context.object.data
    bm = bmesh.new()

    for v in verts:
        bm.verts.new(v.position)

    bm.verts.ensure_lookup_table()
    for i in indices:
        face = (bm.verts[i[0]], bm.verts[i[1]], bm.verts[i[2]])
        try:
            bm.faces.new(face)
        except ValueError:
            # face already exists
            continue
    
    bm.verts.index_update()
    uv_layer = bm.loops.layers.uv.new()
    normals = []
    for face in bm.faces:
        for loop in face.loops:
            original_uv = verts[loop.vert.index].uv
            uv = (
                (original_uv[0] * texcoord_scale[0]) + texcoord_offset[0],
                1 - ((original_uv[1] * texcoord_scale[1]) + texcoord_offset[1])
            )
            loop[uv_layer].uv = uv
            normals.append(verts[loop.vert.index].normal)

    bm.to_mesh(mesh)
    bm.free()

    bpy.ops.object.mode_set(mode='EDIT')
    for v in bmesh.from_edit_mesh(mesh).verts:
        v.select = True
    bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode='OBJECT')

    mesh.normals_split_custom_set(normals)
    mesh.use_auto_smooth = True

    return obj

def import_bit(f, all_indices, is_tri_list, vertices, texcoord_scale, texcoord_offset):
    start = read_int(f)
    end = read_int(f)
    indices = all_indices[start:end]
    if (not is_tri_list):
        indices = convert_to_tri_list(indices)
    
    return create_mesh(vertices, indices, texcoord_scale, texcoord_offset)

def import_bob(f):
    # read texture coordinate scale and offset
    texcoord_scale_x = read_float(f)
    texcoord_scale_y = read_float(f)
    texcoord_offset_x = read_float(f)
    texcoord_offset_y = read_float(f)

    texcoord_scale = (texcoord_scale_x, texcoord_scale_y)
    texcoord_offset = (texcoord_offset_x, texcoord_offset_y)

    bit_count = read_int(f)
    if bit_count == 0:
        return []

    # read bob header
    tri_int = read_int(f)
    is_tri_list = tri_int == 3
    vertex_count = read_int(f)

    # read index buffer
    index_count = read_int(f)
    all_indices = read_short(f, index_count)
    if is_tri_list:
        all_indices = [tuple(all_indices[i:i+3]) for i in range(0, len(all_indices), 3)]

    # read vertices
    vertices = []
    for i in range(vertex_count):
        vertices.append(Vertex())

    read_array(f, lambda f: fill_vertices(f, vertices))

    # read bits
    return [import_bit(f, all_indices, is_tri_list, vertices, texcoord_scale, texcoord_offset) for i in range(bit_count)]

def save_texture_to_file(texture_bytes, texture_path):
    with open(texture_path, 'wb') as texture_file:
        texture_file.write(texture_bytes)

def create_material(texture_set, arrangement_id, meshes):
    try:
        diffuse_image = bpy.data.images.load(texture_set.diffuse)
    except:
        raise NameError('Cannot load image %s' % texture_set.diffuse)
    try:
        normal_image = bpy.data.images.load(texture_set.normal)
    except:
        raise NameError('Cannot load image %s' % texture_set.normal)
    
    diffuse_tex = bpy.data.textures.new('Diffuse', type = 'IMAGE')
    diffuse_tex.image = diffuse_image

    normal_tex = bpy.data.textures.new('Normal', type = 'IMAGE')
    normal_tex.image = normal_image
    normal_tex.use_normal_map = True

    mat = bpy.data.materials.new(arrangement_id)

    diffuse_tex_slot = mat.texture_slots.add()
    diffuse_tex_slot.texture = diffuse_tex
    diffuse_tex_slot.texture_coords = 'UV'
    diffuse_tex_slot.use_map_color_diffuse = True
    diffuse_tex_slot.mapping = 'FLAT'

    normal_tex_slot = mat.texture_slots.add()
    normal_tex_slot.texture = normal_tex
    normal_tex_slot.texture_coords = 'UV'
    normal_tex_slot.use_map_color_diffuse = False
    normal_tex_slot.use_map_normal = True
    normal_tex_slot.normal_factor = 1.0
    normal_tex_slot.mapping = 'FLAT'

    for mesh in meshes:
        mesh.data.materials.append(mat)

def get_settings():
    settings = None

    # save a default settings file if it doesn't exist
    if not os.path.isfile(SETTINGS_PATH):
        settings = DEFAULT_SETTINGS.copy()
        with open(SETTINGS_PATH, 'w') as settings_file:
            json.dump(settings, settings_file)

    # read the settings file
    if settings is None:
        with open(SETTINGS_PATH, 'r') as settings_file:
            settings = json.load(settings_file)
        
    # populate settings with default values if not specified
    has_changed = False
    for key, default_value in DEFAULT_SETTINGS.items():
        if not key in settings:
            settings[key] = default_value
            has_changed = True
    if has_changed:
        with open(SETTINGS_PATH, 'w') as settings_file:
            json.dump(settings, settings_file)
        
    return settings

def import_textures(f, folder_path, arrangement_id):    
    diffuse_bytes = bytearray(read_array(f, read_byte))
    normal_bytes = bytearray(read_array(f, read_byte))
    gearstack_bytes = bytearray(read_array(f, read_byte))
    
    # create textures directory if it doesn't exist
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)

    texture_set = TextureSet()
    texture_set.diffuse = os.path.join(folder_path, arrangement_id + "_diffuse.png")
    texture_set.normal = os.path.join(folder_path, arrangement_id + "_normal.png")
    texture_set.gearstack = os.path.join(folder_path, arrangement_id + "_gearstack.png")
    
    save_texture_to_file(diffuse_bytes, texture_set.diffuse)
    save_texture_to_file(normal_bytes, texture_set.normal)
    save_texture_to_file(gearstack_bytes, texture_set.gearstack)

    return texture_set

def rename_meshes(meshes, arrangement_id):
    for mesh in meshes:
        mesh.name = arrangement_id

def import_arrangement(f, textures_path):
    meshes = [mesh for bits in read_array(f, import_bob) for mesh in bits]
    arrangement_id = read_string(f)
    has_texture_plates = read_int(f)
    if has_texture_plates == 1:
        folder_path = os.path.join(textures_path, arrangement_id)
        texture_set = import_textures(f, folder_path, arrangement_id)
        create_material(texture_set, arrangement_id, meshes)
    rename_meshes(meshes, arrangement_id)

def import_item(context, filepath):
    if not bpy.data.is_saved:
        raise FileNotFoundError("Blender file must be saved to disk.")
    settings = get_settings()
    textures_path = bpy.path.abspath('//' + settings['texture_path'])

    f = open(filepath, 'rb')
    read_array(f, lambda f: import_arrangement(f, textures_path))
    f.close()
    return {'FINISHED'}


# ImportHelper is a helper class, defines filename and
# invoke() function which calls the file selector.
from bpy_extras.io_utils import ImportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty
from bpy.types import Operator


class ImportDestinyItem(Operator, ImportHelper):
    """This appears in the tooltip of the operator and in the generated docs"""
    bl_idname = "import_data.destiny_item"  # important since its how bpy.ops.import_data.destiny_item is constructed
    bl_label = "Import Destiny Item"

    # ImportHelper mixin class uses this
    filename_ext = ".meshes"

    filter_glob = StringProperty(
            default="*.meshes",
            options={'HIDDEN'},
            maxlen=255,  # Max internal buffer length, longer would be clamped.
            )

    def execute(self, context):
        return import_item(context, self.filepath)


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
