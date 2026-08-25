class_name GameConstants
extends Object
## War-room locked constants for Metro Ops 3D (sellable product path).

const MAP_SIZE: int = 128
const CHUNK_SIZE: int = 16
const CHUNKS_PER_SIDE: int = MAP_SIZE / CHUNK_SIZE  # 8
const LOT_METERS: float = 16.0
## Kenney city-kit tiles are ~1 unit; scale to fill a lot with a small setback.
const BUILDING_SCALE: float = 14.5
const ROAD_SCALE: float = 16.0
const PROP_SCALE: float = 14.5

const TARGET_FPS: int = 40
const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 800

const FSR_MODE: int = 2  # FSR2
const FSR_SCALE: float = 0.67
const FSR_SHARPNESS: float = 0.2

const POWER_RADIUS: int = 18
const WATER_RADIUS: int = 15
const FOG_REVEAL_RADIUS: int = 10
const HQ_SERVICE_RADIUS: int = 8

const STARTING_CASH: int = 40000
const ROAD_COST: int = 10
const ZONE_COST: int = 25
const POWER_PLANT_COST: int = 2500
const WATER_TOWER_COST: int = 1500
const POWER_UPKEEP: int = 40
const WATER_UPKEEP: int = 25
const TAX_PER_OCCUPANCY: float = 0.35
## Seed HQ power/water do not charge upkeep; only player-placed services do.
const UPKEEP_GRACE_TICKS: int = 24  # 12s at 0.5s ticks
const PAINT_ZONE_OCCUPANCY: float = 0.45

const WAR_EMBARGO_TAX_MULT: float = 0.45
const WAR_LEVY_HIT: int = 4000
const WAR_DURATION_TICKS: int = 120

const DISASTER_DEMAND_MULT: float = 0.35
const DISASTER_DURATION_TICKS: int = 80

const SIM_TICK_SEC: float = 0.5

const RCI_DEMAND_BASE: float = 0.55
const RCI_DEMAND_MIN: float = 0.08
const RCI_DEMAND_MAX: float = 1.45
const RCI_BALANCE_GAIN: float = 0.55
const TAX_RES: float = 0.28
const TAX_COM: float = 0.42
const TAX_IND: float = 0.38

const WAR_DEMAND_R: float = 0.85
const WAR_DEMAND_C: float = 0.40
const WAR_DEMAND_I: float = 0.55
const DISASTER_DEMAND_R: float = 0.30
const DISASTER_DEMAND_C: float = 0.70
const DISASTER_DEMAND_I: float = 0.75

const CAM_YAW_SPEED: float = 1.8
const CAM_ZOOM_SPEED: float = 64.0
const CAM_ZOOM_SMOOTH: float = 10.0
const CAM_WHEEL_STEP: float = 16.0
const CAM_PAN_SPEED: float = 48.0
## Pulled back above Kenney downtown so the skyline fills the frame (not jammed in AABBs).
const CAM_DIST_MIN: float = 120.0
const CAM_DIST_MAX: float = 620.0
const CAM_DIST_DEFAULT: float = 390.0
const CAM_PITCH_MIN: float = -68.0
const CAM_PITCH_MAX: float = -42.0
const CAM_PITCH_DEFAULT: float = -56.0
const CAM_YAW_DEFAULT: float = 42.0
## HQ skyscraper-d (6.47u × 14.5 × 1.15) ~91 m plus pad — camera Y never under roofs.
const CAM_ROOF_CLEARANCE: float = 108.0
