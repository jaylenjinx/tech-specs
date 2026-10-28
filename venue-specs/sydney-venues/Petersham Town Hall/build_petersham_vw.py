"""Build a Petersham Town Hall main hall and stage model in Vectorworks.

Run inside Vectorworks (2027) in an empty document, for example from a Resource Manager script:
    import runpy; runpy.run_path('/path/to/build_petersham_vw.py')

Source: Inner West (Marrickville) Council floor plan, "Main Hall Space Floor Plans 2014" (plan w/ measurements),
scaled where the plan gives no dimension. Everything is built from extrudes, so it shows in Top/Plan and 3D views.

Coordinates in metres, converted to the document's units:
  origin = centre of the proscenium line (stage face of the proscenium wall), hall floor level
  +X = stage left (house right), +Y = upstage, +Z = up.
"""
import math
import os
import vs

# ---- measurements (metres) ----
STAGE_W_SL, STAGE_W_SR = 5.83, -6.88      # stage walls; 12.71 m wide (dimensioned)
STAGE_D = 7.485                           # proscenium to upstage wall (dimensioned)
STAGE_H = 1.0                             # ASSUMED stage height above hall floor; not on the plan
STAGE_HOUSE_H = 13.625                    # stage house height (3D view)
PROS_HALF = 4.17                          # proscenium opening 8.34 m (scaled off the plan)
PROS_H = 6.5                              # ASSUMED proscenium opening height
PROS_T = 0.5                              # proscenium wall thickness (scaled)
APRON_D = 0.3                             # stage lip projection past the proscenium wall, also its end radius (scaled)
HALL_HALF_W = 18.87 / 2                   # hall internal width (dimensioned)
HALL_L = 24.17                            # hall internal length (dimensioned)
HALL_CEIL = 7.315                         # hall ceiling (dimensioned)
WALL_T = 0.4
DOOR_H = 2.14
SIDE_EXITS = [(-7.96, 1.635), (-12.5, 1.635), (-16.9, 1.68), (-21.5, 1.645)]   # (y centre, width), both side walls
ENTRANCES = [(3.5, 1.69, 2.14), (-3.24, 1.70, 2.13)]                           # back wall (x centre, width, height)
ROLLER = (-0.15, 1.89, 2.985)                                                  # upstage wall (x centre, width, height)

LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build_log.txt')
log_lines = []
def log(*a):
    log_lines.append(' '.join(str(x) for x in a))

upi = vs.GetUnits()[3]                    # document units per inch
K = upi / 0.0254                          # document units per metre
def P(x, y):
    return (x * K, y * K)

def name_last(name, cls):
    h = vs.LNewObj()
    vs.SetClass(h, cls)
    vs.SetName(h, name)
    log('made', name)
    return h

def box(name, cls, x0, y0, x1, y1, z0, z1):
    """Rectangular extrude between two plan corners."""
    if abs(x1 - x0) < 1e-6 or abs(y1 - y0) < 1e-6 or z1 <= z0:
        return None
    vs.BeginXtrd(z0 * K, z1 * K)
    vs.Rect(P(min(x0, x1), max(y0, y1)), P(max(x0, x1), min(y0, y1)))
    vs.EndXtrd()
    return name_last(name, cls)

def prism(name, cls, pts, z0, z1):
    """Polygon extrude from a list of (x, y) points in metres."""
    vs.BeginXtrd(z0 * K, z1 * K)
    vs.ClosePoly()
    vs.BeginPoly()
    for x, y in pts:
        vs.AddPoint(P(x, y))
    vs.EndPoly()
    vs.EndXtrd()
    return name_last(name, cls)

def wall_with_gaps(name, cls, axis, fixed0, fixed1, start, end, gaps, height, base=0.0):
    """Wall along X (axis='x') or Y (axis='y'), with door gaps [(centre, width, door height)].
    Solid pieces run full height; a lintel spans each gap from the door head to the wall top."""
    cuts = sorted((c - w / 2, c + w / 2, dh) for c, w, dh in gaps)
    pos, n = start, 1
    for a, b, dh in cuts:
        for lo, hi, z0, z1, tag in ((pos, a, base, height, 'pier'), (a, b, base + dh, height, 'lintel')):
            if hi - lo > 1e-6:
                if axis == 'x':
                    box('%s %s %d' % (name, tag, n), cls, lo, fixed0, hi, fixed1, z0, z1)
                else:
                    box('%s %s %d' % (name, tag, n), cls, fixed0, lo, fixed1, hi, z0, z1)
                n += 1
        pos = b
    if end - pos > 1e-6:
        if axis == 'x':
            box('%s pier %d' % (name, n), cls, pos, fixed0, end, fixed1, base, height)
        else:
            box('%s pier %d' % (name, n), cls, fixed0, pos, fixed1, end, base, height)

def label(text, x, y, size=24):
    vs.TextSize(size)
    vs.TextOrigin(P(x, y))
    vs.CreateText(text)
    vs.SetClass(vs.LNewObj(), 'PTH-Annotation')

def build():
    vs.Layer('Petersham Town Hall')
    hall_back = -PROS_T - HALL_L
    hx = HALL_HALF_W

    # Hall floor and walls
    box('Hall floor', 'PTH-Floor', -hx, hall_back, hx, -PROS_T, -0.1, 0)
    side_gaps = [(y, w, DOOR_H) for y, w in SIDE_EXITS]
    wall_with_gaps('Hall SL wall', 'PTH-Walls', 'y', hx, hx + WALL_T, hall_back, -PROS_T, side_gaps, HALL_CEIL)
    wall_with_gaps('Hall SR wall', 'PTH-Walls', 'y', -hx - WALL_T, -hx, hall_back, -PROS_T, side_gaps, HALL_CEIL)
    wall_with_gaps('Hall back wall', 'PTH-Walls', 'x', hall_back - WALL_T, hall_back, -hx - WALL_T, hx + WALL_T, ENTRANCES, HALL_CEIL)

    # Proscenium wall and header
    box('Proscenium SL', 'PTH-Walls', PROS_HALF, -PROS_T, hx + WALL_T, 0, 0, STAGE_HOUSE_H)
    box('Proscenium SR', 'PTH-Walls', -hx - WALL_T, -PROS_T, -PROS_HALF, 0, 0, STAGE_HOUSE_H)
    box('Proscenium header', 'PTH-Walls', -PROS_HALF, -PROS_T, PROS_HALF, 0, PROS_H, STAGE_HOUSE_H)

    # Curved plaster corners either side of the proscenium. On the plan each curve runs from beside the
    # opening to the side wall about 4.8 m into the hall, bowing in toward the corner; the corner behind it is solid.
    a, b = hx - PROS_HALF - 0.45, 4.8
    for side, sgn in (('SL', 1), ('SR', -1)):
        pts = [(sgn * hx, -PROS_T)]
        for i in range(13):
            t = math.radians(90 * i / 12)
            pts.append((sgn * (PROS_HALF + 0.45 + a * math.sin(t)), -PROS_T - b + b * math.cos(t)))
        prism('Proscenium corner %s' % side, 'PTH-Walls', pts, 0, HALL_CEIL)

    # Stage deck, stage house walls
    box('Stage deck', 'PTH-Stage', STAGE_W_SR, 0, STAGE_W_SL, STAGE_D, 0, STAGE_H)
    box('Stage house SL wall', 'PTH-Walls', STAGE_W_SL, 0, STAGE_W_SL + WALL_T, STAGE_D + WALL_T, 0, STAGE_HOUSE_H)
    box('Stage house SR wall', 'PTH-Walls', STAGE_W_SR - WALL_T, 0, STAGE_W_SR, STAGE_D + WALL_T, 0, STAGE_HOUSE_H)
    wall_with_gaps('Stage upstage wall', 'PTH-Walls', 'x', STAGE_D, STAGE_D + WALL_T,
                   STAGE_W_SR - WALL_T, STAGE_W_SL + WALL_T, [(ROLLER[0], ROLLER[1], STAGE_H + ROLLER[2])], STAGE_HOUSE_H)

    # Stage lip: fills the floor through the proscenium opening and projects past the wall face into the
    # hall, with rounded ends that tuck in beside the opening where the plaster curves begin (scaled off the plan).
    lip_w, lip_r = PROS_HALF + 0.45, APRON_D
    front = -PROS_T - APRON_D
    pts = [(-PROS_HALF, 0), (PROS_HALF, 0), (PROS_HALF, -PROS_T), (lip_w, -PROS_T)]
    for i in range(1, 10):          # SL end: quarter round from the wall face to the lip front
        t = math.radians(90 * i / 9)
        pts.append((lip_w - lip_r + lip_r * math.cos(t), -PROS_T - lip_r * math.sin(t)))
    for i in range(0, 9):           # SR end, mirrored
        t = math.radians(90 - 90 * i / 9)
        pts.append((-lip_w + lip_r - lip_r * math.cos(t), -PROS_T - lip_r * math.sin(t)))
    pts += [(-lip_w, -PROS_T), (-PROS_HALF, -PROS_T)]
    prism('Stage lip', 'PTH-Stage', pts, 0, STAGE_H)

    # Treads from the hall up to the stage lip, downstage stage-right
    n_steps = max(1, round(STAGE_H / 0.2))
    rise, run = STAGE_H / n_steps, 0.3
    for i in range(n_steps):
        box('Stage treads step %d' % (i + 1), 'PTH-Stage', -PROS_HALF + 0.05, front - run * (n_steps - i), -PROS_HALF + 1.05,
            front - run * (n_steps - i - 1), 0, rise * (i + 1))

    # Dressing rooms
    sl0, sl1 = STAGE_W_SL + WALL_T, STAGE_W_SL + WALL_T + 3.175
    box('Dressing room SL floor', 'PTH-Dressing rooms', sl0, 1.70, sl1, 1.70 + 4.72, STAGE_H - 0.1, STAGE_H)
    for nm, a in (('Dressing room SL outer wall', (sl1, 1.70, sl1 + 0.2, 1.70 + 4.72)),
                  ('Dressing room SL up wall', (sl0, 1.70 + 4.72, sl1 + 0.2, 1.70 + 4.92)),
                  ('Dressing room SL down wall', (sl0, 1.50, sl1 + 0.2, 1.70))):
        box(nm, 'PTH-Dressing rooms', a[0], a[1], a[2], a[3], STAGE_H, STAGE_H + 3.0)
    sr1, sr0 = -9.40 - WALL_T, -9.40 - WALL_T - 3.505
    box('Dressing room SR floor', 'PTH-Dressing rooms', sr0, 0.11, sr1, 0.11 + 7.59, -0.1, 0)
    for nm, a in (('Dressing room SR outer wall', (sr0 - 0.2, 0.11, sr0, 0.11 + 7.59)),
                  ('Dressing room SR up wall', (sr0 - 0.2, 0.11 + 7.59, sr1, 0.11 + 7.79)),
                  ('Dressing room SR down wall', (sr0 - 0.2, -0.09, sr1, 0.11))):
        box(nm, 'PTH-Dressing rooms', a[0], a[1], a[2], a[3], 0, 3.0)
    # spiral stair down to the SR dressing room (position scaled off the plan)
    pts = [(-7.7 + 0.6 * math.cos(math.radians(a)), 5.3 + 0.6 * math.sin(math.radians(a))) for a in range(0, 360, 20)]
    prism('Spiral stair', 'PTH-Dressing rooms', pts, 0, STAGE_H)

    # Labels (Top/Plan)
    label('STAGE  12.71 m x 7.485 m  (94 m2)', -3.5, 4.0, 28)
    label('Stage height %.2f m ASSUMED - confirm on site' % STAGE_H, -3.5, 3.2, 16)
    label('Proscenium opening ~8.34 m (scaled), height %.1f m ASSUMED' % PROS_H, -2.8, -1.3, 16)
    label('MAIN HALL  24.17 m x 18.87 m  (453 m2), ceiling 7.315 m', -6.5, -12.0, 28)
    label('Roller door 1.89 w x 2.985 h', -1.2, STAGE_D + 0.9, 16)
    label('Hall entrances ~1.7 w x 2.14 h', -3.0, hall_back - 1.0, 16)
    label('Dressing room SL 4.72 x 3.175', sl0 + 0.2, 4.2, 14)
    label('Dressing room SR 7.59 x 3.505', sr0 + 0.2, 4.0, 14)
    label('Source: Marrickville Council floor plan 2014 (plan w/ measurements). Origin = proscenium centre, hall floor.',
          -hx, hall_back - 2.2, 12)

try:
    log('units per metre', K)
    build()
    log('done')
except Exception as e:
    import traceback
    log('ERROR', repr(e))
    log(traceback.format_exc())
finally:
    with open(LOG, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log_lines) + '\n')
