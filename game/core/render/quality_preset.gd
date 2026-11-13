# QualityPreset — one video quality level (Low / Medium / High / Ultra, GAME_DESIGN §18). Every
# field is applied at runtime by the Graphics autoload without a restart; only the renderer
# itself (Forward+ vs Compatibility) needs one (`RESTART_ONLY` in graphics.gd).
# Authority: local data.
class_name QualityPreset
extends Resource

enum Scaling { BILINEAR, FSR1, FSR2 }

@export var id: StringName = &""
@export var display_name: String = ""
@export var order: int = 0
@export_group("Resolution & AA")
@export_range(0.25, 2.0) var render_scale: float = 1.0
@export var scaling: Scaling = Scaling.BILINEAR
@export var msaa: Viewport.MSAA = Viewport.MSAA_DISABLED
@export var fxaa: bool = false
@export var taa: bool = false
@export_group("Shadows")
@export var directional_shadow_size: int = 4096
@export var positional_shadow_atlas: int = 4096
@export var soft_shadow_quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
@export var max_shadow_lights: int = 8  # shadow-casting omni/spot lights allowed (ARCHITECTURE §12)
@export_group("Effects")
@export var ssao: bool = true
@export var ssao_quality: RenderingServer.EnvironmentSSAOQuality = RenderingServer.ENV_SSAO_QUALITY_MEDIUM
@export var glow: bool = true
@export var volumetric_fog: bool = true
@export var volumetric_fog_size: int = 64
@export var volumetric_fog_depth: int = 64
@export_range(0.0, 1.0) var particle_density: float = 1.0
@export_group("Detail")
@export var mesh_lod_threshold: float = 1.0  # pixels; higher = coarser LODs sooner
@export var view_distance: float = 250.0  # camera far plane cap (m)
