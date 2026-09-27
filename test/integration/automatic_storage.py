import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = os.environ["COMPOSE_PROJECT_NAME"]
BUCKET = os.environ["AWS_S3_BUCKET"]
IMAGE = "craftplan-storage:test"


def docker(*args, input=None, ok=True, env=None):
    result = subprocess.run(["docker", *args], input=input, env=env, capture_output=True, text=True)
    if ok:
        assert result.returncode == 0, result.stdout + result.stderr
    return result


def compose(path, *args, **kwargs):
    return docker("compose", "-p", PROJECT, "-f", str(path), *args, **kwargs)


def container(service):
    ids = docker("ps", "-aq", "--filter", f"label=com.docker.compose.project={PROJECT}",
                 "--filter", f"label=com.docker.compose.service={service}").stdout.split()
    assert len(ids) == 1, ids
    return json.loads(docker("inspect", ids[0]).stdout)[0]


def write_config(path, value):
    def escape(v):
        if isinstance(v, str):
            return v.replace("$", "$$")
        if isinstance(v, list):
            return [escape(x) for x in v]
        if isinstance(v, dict):
            return {k: escape(x) for k, x in v.items()}
        return v
    path.write_text(json.dumps(escape(value)))


def object_command(*args, input=None):
    env = {
        "RCLONE_CONFIG_NEW_TYPE": "s3", "RCLONE_CONFIG_NEW_PROVIDER": "SeaweedFS",
        "RCLONE_CONFIG_NEW_ENDPOINT": "http://minio:9000",
        "RCLONE_CONFIG_NEW_ACCESS_KEY_ID": os.environ["AWS_ACCESS_KEY_ID"],
        "RCLONE_CONFIG_NEW_SECRET_ACCESS_KEY": os.environ["AWS_SECRET_ACCESS_KEY"],
        "RCLONE_CONFIG_NEW_REGION": "us-east-1",
    }
    command = ["run", "--rm", "-i", "--network", PROJECT + "_default"]
    for name in env:
        command += ["-e", name]
    return docker(
        *command,
        "rclone/rclone:1.75.1",
        "--retries", "1", "--low-level-retries", "1",
        "--timeout", "10s", "--contimeout", "5s", *args,
        input=input,
        env={**os.environ, **env},
    ).stdout


def legacy_hashes(volume):
    return docker("run", "--rm", "--network", "none", "--entrypoint", "sh",
                  "-e", "BUCKET", "-v", volume + ":/legacy:ro", IMAGE, "-ec",
                  'find "/legacy/$BUCKET" -type f -exec sha256sum {} \\; | sort').stdout


fixture = ROOT / "test/integration/docker-compose.yml"
legacy = container("minio")
legacy_volume = next(m["Name"] for m in legacy["Mounts"] if m["Destination"] == "/data")
os.environ["BUCKET"] = BUCKET
before = legacy_hashes(legacy_volume)
assert before
compose(fixture, "stop", "seaweedfs")
compose(fixture, "rm", "-f", "seaweedfs")

with tempfile.TemporaryDirectory(prefix="craftplan-auto-storage-") as directory:
    directory = Path(directory)
    config = {
        "services": {
            "minio": {"extends": {"file": str(ROOT / "docker-compose.yml"), "service": "minio"},
                      "image": IMAGE, "restart": "no"},
            "craftplan": {"image": "rclone/rclone:1.75.1", "entrypoint": ["/bin/sh", "-c"],
                          "command": ["exec sleep 86400"],
                          "depends_on": {"minio": {"condition": "service_healthy"}}},
        },
        "volumes": {
            "minio_data": {"external": True, "name": legacy_volume},
            "seaweedfs_data": {"name": PROJECT + "_automatic_data"},
        },
    }
    target = directory / "compose.json"
    old_port = compose(fixture, "port", "minio", "9000").stdout.strip().split(":")[-1]
    os.environ["S3_PORT"] = old_port
    write_config(target, config)

    fault = directory / "fault"
    fault.mkdir()
    (fault / "rclone").write_text("#!/bin/sh\necho 'Injected transfer failure' >&2\nexit 23\n")
    (fault / "rclone").chmod(0o755)
    failing = copy.deepcopy(config)
    failing["services"]["minio"]["volumes"] = [str(fault) + ":/fault:ro"]
    failing["services"]["minio"]["environment"] = {"PATH": "/fault:/usr/local/bin:/usr/bin:/bin"}
    failed = directory / "failed.json"
    write_config(failed, failing)
    result = compose(failed, "up", "-d", "--wait", "--wait-timeout", "45", ok=False)
    assert result.returncode != 0
    assert container("minio")["State"]["Status"] == "exited"
    assert not container("craftplan")["State"]["Running"]
    logs = docker("logs", container("minio")["Id"])
    assert "Taking a private snapshot" in logs.stdout, logs.stderr + logs.stdout
    assert legacy_hashes(legacy_volume) == before
    print("PASS: plain compose up detects MinIO, preserves the source, and blocks app startup on copy failure", flush=True)

    compose(target, "up", "-d", "--wait", "--wait-timeout", "180")
    storage = container("minio")
    assert container("craftplan")["State"]["Running"]
    assert docker("exec", storage["Id"], "cat", "/data/.craftplan-storage-v1").stdout.strip() == "v1:migrated:" + BUCKET
    assert legacy_hashes(legacy_volume) == before
    assert object_command("cat", f"new:{BUCKET}/nested/space + café.txt") == "legacy metadata"
    docker("exec", storage["Id"], "sh", "-c", "test ! -e /data/.craftplan-minio-snapshot")
    print("PASS: normal compose retry verifies migration, starts the app and retains original data unchanged", flush=True)

    object_command("rcat", f"new:{BUCKET}/nested/space + café.txt", input="newer upload")
    object_command("deletefile", f"new:{BUCKET}/empty")
    compose(target, "up", "-d", "--force-recreate", "--wait", "--wait-timeout", "120")
    storage = container("minio")
    assert object_command("cat", f"new:{BUCKET}/nested/space + café.txt") == "newer upload"
    assert "empty" not in object_command("lsf", f"new:{BUCKET}").splitlines()
    logs = docker("logs", storage["Id"]).stdout
    assert "MinIO data detected" not in logs
    assert "migration is not required" in logs
    assert legacy_hashes(legacy_volume) == before
    print("PASS: SeaweedFS upgrades skip migration, preserve new uploads and do not resurrect deleted objects", flush=True)

    compose(target, "stop", "craftplan", "minio")
    fresh = copy.deepcopy(config)
    fresh["volumes"]["minio_data"] = {"name": PROJECT + "_empty_legacy"}
    fresh["volumes"]["seaweedfs_data"] = {"name": PROJECT + "_fresh_data"}
    fresh_file = directory / "fresh.json"
    write_config(fresh_file, fresh)
    try:
        compose(fresh_file, "up", "-d", "--force-recreate", "--wait", "--wait-timeout", "120")
        storage = container("minio")
        assert docker("exec", storage["Id"], "cat", "/data/.craftplan-storage-v1").stdout.strip() == "v1:native:" + BUCKET
        object_command("rcat", f"new:{BUCKET}/fresh", input="fresh data")
        compose(fresh_file, "up", "-d", "--force-recreate", "--wait", "--wait-timeout", "120")
        assert object_command("cat", f"new:{BUCKET}/fresh") == "fresh data"
        print("PASS: clean installs and subsequent native SeaweedFS upgrades need no migration", flush=True)

        native = copy.deepcopy(fresh)
        native["volumes"]["seaweedfs_data"] = {"external": True, "name": PROJECT + "_seaweedfs_data"}
        native_file = directory / "native.json"
        write_config(native_file, native)
        compose(native_file, "up", "-d", "--force-recreate", "--wait", "--wait-timeout", "120")
        assert object_command("cat", f"new:{BUCKET}/nested/space + café.txt") == "legacy metadata"
        assert "MinIO data detected" not in docker("logs", container("minio")["Id"]).stdout
        print("PASS: existing unmarked SeaweedFS data is preserved without a legacy migration", flush=True)
    finally:
        compose(fresh_file, "down", "-v", "--remove-orphans")
        docker("volume", "rm", PROJECT + "_automatic_data")
print("Fully automatic Compose storage integration: all checks passed.", flush=True)
