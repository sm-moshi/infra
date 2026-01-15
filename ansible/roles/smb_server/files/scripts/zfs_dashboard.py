#!/usr/bin/env python3
"""
Lightweight curses dashboard for ZFS pools.
Test on the Proxmox host; requires zpool/zfs and /proc/spl/kstat/zfs/arcstats.
Press q to quit.
"""
import curses
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

POOLS = ["timemachine", "datengrab"]
ARCSTATS = Path("/proc/spl/kstat/zfs/arcstats")
REFRESH_SECONDS = 2


@dataclass
class ArcStats:
    arc_hits: int = 0
    arc_misses: int = 0
    l2_hits: int = 0
    l2_misses: int = 0
    size: int = 0
    c_max: int = 0


@dataclass
class PoolSample:
    name: str
    ops_r: float
    ops_w: float
    bw_r_mb: float
    bw_w_mb: float


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def read_arc() -> ArcStats:
    if not ARCSTATS.exists():
        return ArcStats()
    data = {}
    for line in ARCSTATS.read_text().splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        try:
            data[parts[0]] = int(parts[2], 0)  # handles hex (0x...) or decimal
        except ValueError:
            continue
    return ArcStats(
        arc_hits=data.get("hits", 0),
        arc_misses=data.get("misses", 0),
        l2_hits=data.get("l2_hits", 0),
        l2_misses=data.get("l2_misses", 0),
        size=data.get("size", 0),
        c_max=data.get("c_max", 0),
    )


def format_ratio(numer: int, denom: int) -> str:
    return "n/a" if denom == 0 else f"{(numer * 100) / denom:.2f}%"


def draw_table(win, y, x, headers, rows, widths, row_attrs=None):
    def line(chars):
        win.addstr(y, x, chars)

    sep = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
    line(sep)
    y += 1
    header_cells = "| " + " | ".join(f"{h:<{w}}" for h, w in zip(headers, widths)) + " |"
    line(header_cells)
    y += 1
    line(sep)
    y += 1
    for idx, row in enumerate(rows):
        row_cells = "| " + " | ".join(f"{str(val):<{w}}"[:w] for val, w in zip(row, widths)) + " |"
        attr = 0
        if row_attrs and idx < len(row_attrs):
            attr = row_attrs[idx]
        line(row_cells if not attr else "")
        if attr:
            win.addstr(y, x, row_cells, attr)
        y += 1
        continue
        y += 1
    line(sep)
    return y + 1


def sample_pools_numeric(pools: list[str]) -> list[PoolSample]:
    if not pools:
        return []
    out = _run(["zpool", "iostat", "-vyp", *pools, "1", "1"])
    samples: list[PoolSample] = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 7 or parts[0] not in pools:
            continue
        name, *_rest = parts
        _, _, _, ops_r, ops_w, bw_r_b, bw_w_b = parts
        samples.append(
            PoolSample(
                name=name,
                ops_r=float(ops_r),
                ops_w=float(ops_w),
                bw_r_mb=float(bw_r_b) / 1024 / 1024,
                bw_w_mb=float(bw_w_b) / 1024 / 1024,
            )
        )
    return samples


def sample_pools_human(pools: list[str]) -> list[str]:
    if not pools:
        return []
    out = _run(["zpool", "iostat", "-vy", *pools, "1", "1"])
    return out.splitlines()


def dataset_props(datasets: list[str]) -> list[tuple[str, str, str, str, str]]:
    rows = []
    for ds in datasets:
        try:
            recordsize = _run(["zfs", "get", "-H", "-o", "value", "recordsize", ds]).strip()
            sync = _run(["zfs", "get", "-H", "-o", "value", "sync", ds]).strip()
            logbias = _run(["zfs", "get", "-H", "-o", "value", "logbias", ds]).strip()
            primarycache = _run(["zfs", "get", "-H", "-o", "value", "primarycache", ds]).strip()
        except subprocess.CalledProcessError:
            recordsize = sync = logbias = primarycache = "n/a"
        rows.append((ds, recordsize, sync, logbias, primarycache))
    return rows


def draw(stdscr):
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_GREEN, -1)
    curses.init_pair(2, curses.COLOR_YELLOW, -1)
    curses.init_pair(3, curses.COLOR_CYAN, -1)
    curses.init_pair(4, curses.COLOR_MAGENTA, -1)

    curses.curs_set(0)
    stdscr.nodelay(True)
    datasets = [
        "timemachine",
        "timemachine/tm-smb",
        "datengrab",
        "datengrab/archive",
        "datengrab/media",
    ]
    win = None
    win_h = win_w = 0

    while True:
        key = stdscr.getch()
        if key in (ord("q"), ord("Q")):
            break

        term_h, term_w = stdscr.getmaxyx()

        arc = read_arc()
        total = arc.arc_hits + arc.arc_misses
        l2_total = arc.l2_hits + arc.l2_misses
        # Gather data needed for layout sizing
        samples = sample_pools_numeric(POOLS)
        props_rows = dataset_props(datasets)
        iostat_lines = sample_pools_human(POOLS)

        # Estimate content height and width
        props_start = 9 + len(samples) + 1
        io_start = props_start + 3 + len(datasets)
        # Use most of the terminal to avoid truncating iostat
        content_width = max(
            80,
            max((len(line) for line in iostat_lines), default=0) + 6,
        )
        box_h = term_h - 1 if term_h > 2 else term_h
        box_w = min(term_w, content_width)

        if win is None or box_h != win_h or box_w != win_w:
            win = curses.newwin(box_h, box_w, 0, 0)
            win_h, win_w = box_h, box_w
        else:
            win.erase()

        stdscr.erase()
        stdscr.noutrefresh()

        win.border()
        win.addstr(0, 2, f" ZFS dashboard (q to quit) – {time.strftime('%Y-%m-%d %H:%M:%S')} ")

        y_off, x_off = 1, 2

        win.addstr(1 + y_off, 0 + x_off, "ARC/L2ARC", curses.color_pair(3) | curses.A_BOLD)
        arc_rows = [
            ("ARC hit ratio", format_ratio(arc.arc_hits, total)),
            ("L2ARC hit ratio", format_ratio(arc.l2_hits, l2_total)),
            ("ARC size/max (MiB)", f"{arc.size/1024/1024:.1f} / {arc.c_max/1024/1024:.1f}"),
        ]
        cur_y = 2 + y_off
        cur_y = draw_table(win, cur_y, x_off, ["Metric", "Value"], arc_rows, [18, 24])

        win.addstr(cur_y, 0 + x_off, "Pool load (1s sample)", curses.color_pair(4) | curses.A_BOLD)
        pool_rows = []
        pool_attrs = []
        for s in samples:
            pool_rows.append((s.name, f"{s.ops_r:,.0f}/{s.ops_w:,.0f}", f"{s.bw_r_mb:.1f}/{s.bw_w_mb:.1f}"))
            pool_attrs.append(curses.color_pair(1 if s.bw_w_mb <= 100 else 2))
        cur_y = draw_table(win, cur_y + 1, x_off, ["pool", "ops r/w", "bw r/w (MB/s)"], pool_rows, [12, 14, 18], pool_attrs)

        win.addstr(cur_y, 0 + x_off, "Dataset config", curses.color_pair(3) | curses.A_BOLD)
        ds_rows = [(ds, rec, sync, logbias, primary) for ds, rec, sync, logbias, primary in props_rows]
        cur_y = draw_table(win, cur_y + 1, x_off, ["dataset", "recordsize", "sync", "logbias", "primarycache"], ds_rows, [25, 12, 8, 10, 12])

        win.addstr(cur_y, 0 + x_off, "ZPOOL IOSTAT (1s sample)", curses.color_pair(4) | curses.A_BOLD)
        # Fit iostat lines into remaining height
        max_lines = box_h - cur_y - 3
        for j, line in enumerate(iostat_lines[: max_lines], start=cur_y + 1):
            win.addstr(j, 2 + x_off, line[: max(0, box_w - 4)])

        win.noutrefresh()
        curses.doupdate()
        time.sleep(REFRESH_SECONDS)


def main():
    curses.wrapper(draw)


if __name__ == "__main__":
    main()
