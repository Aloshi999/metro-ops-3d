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
## MegaKit downtown prebuilts are authored in meters (1 unit = 1 m). Do not use 14.5 —
## that squashes 28 m midrise and kills skyline height. Measured AABB (Y-up):
## Building_Large_2 20.64 × 16.64 × 28.00 m (X > 16 m → 2-lot / 32 m pad);
## Building_Medium_2_001 15.06 × 13.06 × 25.01 m (one 16 m lot);
## Building_Small_1 12.46 × 14.54 × 17.03 m (one 16 m lot).
const DISTRICT_DOWNTOWN_SCALE: float = 1.0
const DISTRICT_LARGE_LOTS: int = 2  # Large_2 pad

const TARGET_FPS: int = 40
const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 800
## Chrome safe rect at 1280×800: left/top/bottom ≥48, right ≤1184 (QAM 96).
const HUD_SAFE := Rect2(48, 48, 1136, 704)
const HUD_MARGIN_L: int = 48
const HUD_MARGIN_T: int = 48
const HUD_MARGIN_R: int = 96
const HUD_MARGIN_B: int = 48

## Deck overscan + Steam QAM strip. Design res 1280×800.
## Left/top/bottom ≥ 48; right edge ≤ 1184 (96px QAM).
const HUD_SAFE_LEFT: float = 48.0
const HUD_SAFE_TOP: float = 48.0
const HUD_SAFE_RIGHT: float = 1184.0
const HUD_SAFE_BOTTOM: float = 752.0
const HUD_SAFE_RECT := Rect2(48, 48, 1136, 704)


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

const WAR_EMBARGO_TAX_START: float = 0.85
const WAR_EMBARGO_TAX_MULT: float = 0.45  # embargo ceiling (worst)
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

## Lots fill only when demand is hotter than this and the lot is powered+watered+roaded.
const FILL_DEMAND_MIN: float = 0.40

## Corridor interdiction — trade/roads spine (3 adjacent chunks).
const CORRIDOR_DURATION_TICKS: int = 120
const CORRIDOR_TAX_MULT: float = 0.80
const CORRIDOR_TRADE_MULT: float = 0.33
const CORRIDOR_DEMAND_R: float = 0.85
const CORRIDOR_DEMAND_C: float = 0.45
const CORRIDOR_DEMAND_I: float = 0.55
const CORRIDOR_LAND_MULT: float = 0.70
const CORRIDOR_CHUNKS: int = 3

## Grid blackout — power off on one plant chunk. Hours-scale (24 ticks).
const BLACKOUT_DURATION_TICKS: int = 24
const BLACKOUT_TAX_MULT: float = 0.90
const BLACKOUT_TRADE_MULT: float = 0.85
const BLACKOUT_DEMAND_R: float = 0.90
const BLACKOUT_DEMAND_C: float = 0.70
const BLACKOUT_DEMAND_I: float = 0.55

## Dock walkout — waterfront/com trade smash. No chunk damage.
const WALKOUT_DURATION_TICKS: int = 48
const WALKOUT_TAX_MULT: float = 0.95
const WALKOUT_TRADE_MULT: float = 0.20
const WALKOUT_DEMAND_C: float = 0.65
const WALKOUT_DEMAND_I: float = 0.70
const WALKOUT_WATERFRONT_C: float = 0.50
const EMBARGO_TRADE_MULT: float = 0.50
const FLOOD_CHUNKS: int = 2
const FLOOD_LAND_MULT: float = 0.92
const FLOOD_TRADE_MULT: float = 0.80
const CORRIDOR_ROAD_MULT: float = 0.55
const BLACKOUT_CHUNK_COUNT: int = 2

## Quake — extend disaster damage, I rebuild pull.
const QUAKE_DURATION_TICKS: int = 80
const QUAKE_TAX_MULT: float = 0.94
const QUAKE_TRADE_MULT: float = 0.90
const QUAKE_DEMAND_R: float = 0.30
const QUAKE_DEMAND_C: float = 0.70
const QUAKE_DEMAND_I: float = 1.15
const QUAKE_LAND_MULT: float = 0.75

const OPINION_MIN: float = 0.55
const OPINION_MAX: float = 1.25
const JOB_TAX: float = 0.08
const TRADE_BONUS: float = 0.10
const LAND_VALUE_TAX: float = 0.04

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
