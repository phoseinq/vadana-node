import os

from PIL import Image

from vadana_node.render import video
from vadana_node.render.whiteboard import Shape, Whiteboard


def _pencil(page, t):
    return (t, page, f"s{t}", Shape("pencil", 1, t, pts=[(100.0, 100.0), (200.0, 200.0)]))


def test_render_modules_import():
    # the four copied modules import cleanly (relative imports survived the copy)
    assert hasattr(video, "make_full_video")
    assert hasattr(video, "make_media_video")
    assert hasattr(video, "build_frames")


def test_build_frames_renders_to_disk(tmp_path):
    events = [_pencil((0, 0), 1000), _pencil((0, 1), 30000)]
    nav = [(1000, (0, 0)), (5000, (0, 1))]
    board = Whiteboard(final={(0, 0): {}, (0, 1): {}}, events=events, nav=nav)
    bg = {(0, 0): Image.new("RGB", (40, 30), "white"),
          (0, 1): Image.new("RGB", (40, 30), "white")}
    frames = video.build_frames(board, str(tmp_path), scale=1, max_fps=2.0, backgrounds=bg)
    assert frames                                       # produced at least one frame
    assert all(os.path.exists(p) for _, p in frames)    # each frame png landed on disk
    ts = [t for t, _ in frames]
    assert ts == sorted(ts)                             # time-ordered
