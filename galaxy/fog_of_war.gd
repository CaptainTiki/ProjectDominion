extends MeshInstance3D
class_name FogOfWar

## Fog-of-war overlay for the GalaxyMap.
##
## Uses an RG mask texture:
##   R = explored (ever seen)
##   G = currently visible (active vision)
##
## We start fully revealed (so v0.1 gameplay is unchanged) and provide
## paint helpers for the upcoming intel system.

@export var start_fully_revealed: bool = true

var _size: int = 0
var _img: Image
var _tex: ImageTexture

func setup(size: int) -> void:
    _size = max(1, size)
    _ensure_unique_material()
    _build_mask_texture(_size)

func set_all_visible() -> void:
    if _img == null:
        return
    for y in range(_size):
        for x in range(_size):
            _img.set_pixel(x, y, Color(1, 1, 0, 1))
    _push_update()

func set_all_hidden() -> void:
    if _img == null:
        return
    for y in range(_size):
        for x in range(_size):
            _img.set_pixel(x, y, Color(0, 0, 0, 1))
    _push_update()

func set_cell_explored(tile: Vector2i, explored: bool) -> void:
    if _img == null:
        return
    if tile.x < 0 or tile.y < 0 or tile.x >= _size or tile.y >= _size:
        return
    var c := _img.get_pixel(tile.x, tile.y)
    c.r = 1.0 if explored else 0.0
    # Do not change visibility channel.
    _img.set_pixel(tile.x, tile.y, c)
    _push_update()

func set_cell_visible(tile: Vector2i, visible: bool) -> void:
    if _img == null:
        return
    if tile.x < 0 or tile.y < 0 or tile.x >= _size or tile.y >= _size:
        return
    var c := _img.get_pixel(tile.x, tile.y)
    if visible:
        c.r = 1.0 # visible implies explored
        c.g = 1.0
    else:
        c.g = 0.0
    _img.set_pixel(tile.x, tile.y, c)
    _push_update()

func _build_mask_texture(size: int) -> void:
    _img = Image.create(size, size, false, Image.FORMAT_RGBA8)
    if start_fully_revealed:
        _img.fill(Color(1, 1, 0, 1)) # explored + visible
    else:
        _img.fill(Color(0, 0, 0, 1)) # hidden

    _tex = ImageTexture.create_from_image(_img)
    var mat := get_active_material(0) as ShaderMaterial
    if mat != null:
        mat.set_shader_parameter("fog_tex", _tex)

func _push_update() -> void:
    # Updating every pixel change is fine for now; later we can batch updates.
    if _tex != null and _img != null:
        _tex.update(_img)

func _ensure_unique_material() -> void:
    var mat := get_active_material(0) as ShaderMaterial
    if mat == null:
        return
    # Ensure this instance has its own material so runtime changes don't affect the editor.
    mat = mat.duplicate(true)
    set_surface_override_material(0, mat)
