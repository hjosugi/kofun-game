#!/usr/bin/env python3
"""Run all seven Phaser modes in a real headless Firefox canvas."""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


class Marionette:
    def __init__(self, port: int) -> None:
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.next_id = 1
        greeting = self._receive()
        if greeting.get("marionetteProtocol") != 3:
            raise RuntimeError(f"Unexpected Marionette greeting: {greeting}")

    def _receive(self) -> Any:
        length_bytes = bytearray()
        while True:
            byte = self.socket.recv(1)
            if not byte:
                raise RuntimeError("Marionette closed the connection")
            if byte == b":":
                break
            length_bytes.extend(byte)
        remaining = int(length_bytes.decode("ascii"))
        payload = bytearray()
        while len(payload) < remaining:
            chunk = self.socket.recv(remaining - len(payload))
            if not chunk:
                raise RuntimeError("Incomplete Marionette response")
            payload.extend(chunk)
        return json.loads(payload)

    def request(self, method: str, params: dict[str, Any]) -> Any:
        request_id = self.next_id
        self.next_id += 1
        message = json.dumps(
            [0, request_id, method, params], separators=(",", ":")
        ).encode()
        self.socket.sendall(str(len(message)).encode() + b":" + message)
        response = self._receive()
        if response[1] != request_id:
            raise RuntimeError(f"Marionette response id mismatch: {response}")
        if response[2]:
            raise RuntimeError(f"{method} failed: {response[2]}")
        return response[3]

    def script(self, source: str) -> Any:
        result = self.request(
            "WebDriver:ExecuteScript",
            {
                "script": source,
                "args": [],
                "newSandbox": True,
                "sandbox": "default",
                "line": 0,
                "filename": "kofun-browser-smoke",
            },
        )
        return result["value"]

    def close(self) -> None:
        try:
            self.request("WebDriver:DeleteSession", {})
        finally:
            self.socket.close()


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def wait_for_url(url: str, timeout: float = 10) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                if response.status == 200:
                    return
        except OSError:
            time.sleep(0.1)
    raise RuntimeError(f"Preview server did not become ready: {url}")


def wait_for_marionette(port: int, timeout: float = 10) -> Marionette:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        try:
            return Marionette(port)
        except OSError as error:
            last_error = error
            time.sleep(0.1)
    raise RuntimeError("Firefox Marionette did not become ready") from last_error


def terminate(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def main() -> None:
    firefox = os.environ.get("FIREFOX_BIN") or shutil.which("firefox")
    if not firefox:
        raise RuntimeError("Firefox not found; set FIREFOX_BIN to its path")

    web_port = free_port()
    marionette_port = free_port()
    base_url = f"http://127.0.0.1:{web_port}/"
    server = subprocess.Popen(
        [
            "npm",
            "run",
            "preview",
            "--",
            "--host",
            "127.0.0.1",
            "--port",
            str(web_port),
        ],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    browser: subprocess.Popen[bytes] | None = None
    client: Marionette | None = None
    try:
        wait_for_url(base_url)
        with tempfile.TemporaryDirectory(prefix="kofun-firefox-") as profile:
            Path(profile, "user.js").write_text(
                f'user_pref("marionette.port", {marionette_port});\n'
            )
            browser = subprocess.Popen(
                [
                    firefox,
                    "--headless",
                    "--marionette",
                    "--profile",
                    profile,
                    "about:blank",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            client = wait_for_marionette(marionette_port)
            client.request(
                "WebDriver:NewSession",
                {"capabilities": {"alwaysMatch": {}}},
            )

            for game_number in range(1, 8):
                client.request(
                    "WebDriver:Navigate",
                    {"url": f"{base_url}?game={game_number}"},
                )
                deadline = time.monotonic() + 8
                snapshot = None
                while time.monotonic() < deadline:
                    snapshot = client.script(
                        """
                        const game = document.querySelector("#game");
                        const canvas = document.querySelector("canvas");
                        const frame = Number(game?.dataset.runtimeFrame || 0);
                        return {
                          runtime: frame ? {
                            frame,
                            mode: Number(game.dataset.activeGame) - 1,
                            title: game.dataset.runtimeTitle,
                            ended: game.dataset.runtimeEnded === "true"
                          } : null,
                          errors: JSON.parse(
                            document.documentElement.dataset.runtimeErrors
                              || "[]"
                          ),
                          canvas: canvas ? {
                            width: canvas.width,
                            height: canvas.height
                          } : null,
                          controls: document.querySelectorAll(
                            ".game-controls button"
                          ).length
                        };
                        """
                    )
                    runtime = snapshot["runtime"]
                    if (
                        runtime
                        and runtime["mode"] == game_number - 1
                        and runtime["frame"] >= 2
                    ):
                        break
                    time.sleep(0.05)

                assert snapshot is not None
                assert snapshot["errors"] == [], snapshot["errors"]
                assert snapshot["canvas"] == {"width": 960, "height": 540}
                assert snapshot["controls"] == 6
                assert snapshot["runtime"]["mode"] == game_number - 1
                assert snapshot["runtime"]["frame"] >= 2
                print(
                    f"ok {game_number}/7 "
                    f"{snapshot['runtime']['title']} "
                    f"frame={snapshot['runtime']['frame']}"
                )
    finally:
        if client:
            try:
                client.close()
            except (OSError, RuntimeError):
                pass
        if browser:
            terminate(browser)
        terminate(server)


if __name__ == "__main__":
    main()
