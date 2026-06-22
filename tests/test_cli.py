from vadana_node import cli


def test_config_roundtrip(tmp_path):
    cfgp = str(tmp_path / "config.json")
    cli.main(["config", "--master", "https://h:8443",
              "--ca", "ca.crt", "--cert", "n.crt", "--key", "n.key",
              "--poll", "9", "--config", cfgp])
    c = cli._load(cfgp)
    assert c.master == "https://h:8443"
    assert c.ca == "ca.crt" and c.cert == "n.crt" and c.key == "n.key"
    assert c.poll_interval == 9.0
