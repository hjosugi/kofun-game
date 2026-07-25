from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

ENGINES = {
    "godot-gdscript": "project.godot",
    "raylib-c": "CMakeLists.txt",
    "defold-lua": "game.project",
    "love2d-lua": "main.lua",
    "phaser-typescript": "package.json",
    "macroquad-rust": "Cargo.toml",
    "ebitengine-go": "go.mod",
}

GAME_MARKERS = (
    "COURIER",
    "BREAKER",
    "TAP PATROL",
    "SKY DODGE",
    "DASH",
    "KOFUN ORBIT",
    "SNAKE",
)

EXCLUDED_SOURCE_DIRS = {
    ".godot",
    ".internal",
    "build",
    "dist",
    "node_modules",
    "target",
}


def source_text(project: Path) -> str:
    parts: list[str] = []
    for path in project.rglob("*"):
        relative = path.relative_to(project)
        if EXCLUDED_SOURCE_DIRS.intersection(relative.parts):
            continue
        if path.is_file() and path.suffix in {
            ".c",
            ".gd",
            ".go",
            ".gui_script",
            ".lua",
            ".md",
            ".rs",
            ".script",
            ".ts",
        }:
            parts.append(path.read_text(encoding="utf-8"))
    return "\n".join(parts).upper()


class MatrixStructureTests(unittest.TestCase):
    def test_all_seven_engine_projects_exist(self) -> None:
        self.assertEqual(7, len(ENGINES))
        for engine, entrypoint in ENGINES.items():
            with self.subTest(engine=engine):
                self.assertTrue((ROOT / "engines" / engine / entrypoint).is_file())

    def test_every_engine_names_all_seven_games(self) -> None:
        for engine in ENGINES:
            text = source_text(ROOT / "engines" / engine)
            for marker in GAME_MARKERS:
                with self.subTest(engine=engine, game=marker):
                    self.assertIn(marker, text)

    def test_every_engine_documents_menu_and_restart(self) -> None:
        for engine in ENGINES:
            readme = (ROOT / "engines" / engine / "README.md").read_text(
                encoding="utf-8"
            )
            with self.subTest(engine=engine):
                self.assertRegex(readme.lower(), r"(escape|esc)")
                self.assertRegex(readme.lower(), r"(enter|restart|再開)")

    def test_no_placeholder_markers_in_game_sources(self) -> None:
        forbidden = re.compile(r"\b(TODO|FIXME|PLACEHOLDER|NOT IMPLEMENTED)\b")
        for engine in ENGINES:
            text = source_text(ROOT / "engines" / engine)
            with self.subTest(engine=engine):
                self.assertIsNone(forbidden.search(text))

    def test_runtime_sources_are_ascii_safe(self) -> None:
        runtime_suffixes = {".c", ".gd", ".go", ".gui_script", ".lua", ".rs", ".ts"}
        for path in (ROOT / "engines").rglob("*"):
            relative = path.relative_to(ROOT / "engines")
            if EXCLUDED_SOURCE_DIRS.intersection(relative.parts):
                continue
            if path.is_file() and path.suffix in runtime_suffixes:
                with self.subTest(path=path.relative_to(ROOT)):
                    path.read_text(encoding="ascii")

    def test_research_site_and_play_link_exist(self) -> None:
        index = (ROOT / "site" / "index.html").read_text(encoding="utf-8")
        research = (ROOT / "site" / "research.html").read_text(encoding="utf-8")
        self.assertIn("play/", index)
        for engine in ENGINES:
            self.assertIn(engine, research)

    def test_asset_attribution_is_present(self) -> None:
        credits = (ROOT / "ASSETS.md").read_text(encoding="utf-8")
        self.assertIn("CC BY 4.0", credits)
        self.assertIn("kofun-friends", credits)


if __name__ == "__main__":
    unittest.main()
