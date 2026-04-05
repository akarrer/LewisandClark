"""Hex map logic and waypoint display helpers."""

from __future__ import annotations

from lewis_clark import assets


def get_season(m: int) -> str:
    if m in (3, 4, 5):
        return "Spring"
    if m in (6, 7, 8):
        return "Summer"
    if m in (9, 10, 11):
        return "Autumn"
    return "Winter"


def wp_display_name(wp_id: int, visited_hexes) -> str:
    """Return display name — generic until visited."""
    wp = assets.WAYPOINTS[wp_id]
    hk = assets.WP_HEX[wp_id]
    if wp["revealed"] or tuple(hk) in [tuple(h) for h in visited_hexes]:
        return wp["name"]
    return assets.WP_GENERIC.get(wp["type"], "Unknown Settlement")


def _seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return ((px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2) ** 0.5


def hex_terrain(col: int, row: int) -> str:
    """Return terrain string for hex (col, row).

    Classification uses **hard-coded** column/row bands and ``RIVER_PATHS`` from
    config. It is *not* driven by ``TERRAIN_DATA.json`` (that file only supplies
    costs/labels per terrain type). River corridors are evaluated before mountains
    so rivers can pass through the Rocky band. Change grid size in JSON without
    updating this logic and terrain buckets may no longer match the map.
    """
    if col <= 2:
        return "coast"
    if row <= 2 or row >= 15:
        return "plains"
    # River corridors checked first — they can pass through mountains
    for path in assets.RIVER_PATHS:
        for i in range(len(path) - 1):
            ac, ar = path[i]
            bc, br = path[i + 1]
            if _seg_dist(col, row, ac, ar, bc, br) <= 0.85:
                return "river"
    # Rocky Mountains — only if not on a river corridor
    if col <= 8 and 3 <= row <= 9:
        return "mountain"
    if col <= 11 and 4 <= row <= 8:
        return "forest"
    return "plains"


def _build_hex_contents() -> None:
    """Populate hex contents — settlements, tribes, resources."""
    hc = assets.HEX_CONTENTS
    hc.clear()

    for wp_id, (col, row) in assets.WP_HEX.items():
        wp = assets.WAYPOINTS[wp_id]
        hc[(col, row)] = {
            "type": "waypoint",
            "wp_id": wp_id,
            "name": wp["name"],
            "generic": assets.WP_GENERIC.get(wp["type"], "Settlement"),
            "desc": wp["desc"],
            "wp_type": wp["type"],
        }

    for tribe_key, (col, row) in assets.TRIBE_LOCS.items():
        if (col, row) not in hc:
            hc[(col, row)] = {
                "type": "tribe",
                "tribe_key": tribe_key,
                "name": assets.TRIBES[tribe_key]["name"],
                "desc": f"A {assets.TRIBES[tribe_key]['name']} village.",
            }

    for (col, row), rtype, name, desc, effect in assets.RESOURCES:
        if (col, row) not in hc:
            hc[(col, row)] = {
                "type": "resource",
                "rtype": rtype,
                "name": name,
                "desc": desc,
                "effect": effect,
                "used": False,
            }

    for (col, row), text in assets.RUMOURS:
        if (col, row) not in hc:
            hc[(col, row)] = {
                "type": "rumour",
                "name": "Local Knowledge",
                "desc": text,
            }


def hex_distance(col1: int, row1: int, col2: int, row2: int) -> int:
    """Cube distance (max of axial differences) for offset hex coordinates."""

    def to_cube(c: int, r: int):
        x = c - (r - (r & 1)) // 2
        z = r
        return x, -x - z, z

    x1, y1, z1 = to_cube(col1, row1)
    x2, y2, z2 = to_cube(col2, row2)
    return max(abs(x1 - x2), abs(y1 - y2), abs(z1 - z2))


def next_waypoint_goal_caption(current_wp: int, hex_col: int, hex_row: int) -> str | None:
    """Human-readable next-waypoint line for the objectives panel, or None if none."""
    next_wp_id = current_wp + 1
    nwp = len(assets.WAYPOINTS)
    if next_wp_id >= nwp or next_wp_id >= 10:
        return None
    wp = assets.WAYPOINTS[next_wp_id]
    nwc, nwr = assets.WP_HEX[next_wp_id]
    dist = hex_distance(hex_col, hex_row, nwc, nwr)
    return f"Goal: {wp['name']} · {dist} hexes away"


def hex_neighbours(col: int, row: int):
    """Return valid (col, row) neighbours for pointy-top offset hexes."""
    if row % 2 == 0:
        dirs = [(1, 0), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 1)]
    else:
        dirs = [(1, 0), (-1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1)]
    result = []
    for dc, dr in dirs:
        nc, nr = col + dc, row + dr
        if 0 <= nc < assets.HEX_COLS and 0 <= nr < assets.HEX_ROWS:
            result.append((nc, nr))
    return result


def hex_to_world(col: int, row: int):
    """Convert hex (col, row) to normalised world coords (0-1)."""
    wx = col / (assets.HEX_COLS - 1)
    wy = row / (assets.HEX_ROWS - 1)
    return wx, wy


def world_to_hex(wx, wy):
    """Convert world coords to nearest hex."""
    col = max(0, min(assets.HEX_COLS - 1, round(wx * (assets.HEX_COLS - 1))))
    row = max(0, min(assets.HEX_ROWS - 1, round(wy * (assets.HEX_ROWS - 1))))
    return col, row
