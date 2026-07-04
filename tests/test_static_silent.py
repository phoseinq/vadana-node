from vadana_node.render.video import _static_silent


def test_lone_frame_no_audio_is_static_silent():
    assert _static_silent([(0.0, "a")], None, False)


def test_audio_holds_the_frame():
    assert not _static_silent([(0.0, "a")], "master.m4a", False)


def test_spanning_frames_ok():
    assert not _static_silent([(0.0, "a"), (30.0, "b")], None, False)


def test_screenshare_ok():
    assert not _static_silent([(0.0, "a")], None, True)
