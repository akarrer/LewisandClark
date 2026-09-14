"""Application loop and scene switching."""

from __future__ import annotations

import sys
from enum import Enum, auto

import pygame

from lewis_clark import assets, legs
from lewis_clark.fonts import load_fonts
from lewis_clark.input import InputState
from lewis_clark.region import build_world
from lewis_clark.save_load import load_expedition_json, save_expedition_json
from lewis_clark.screens.cinematic import CinematicScreen
from lewis_clark.screens.expedition import DEPART, VIEW, ExpeditionMapScreen
from lewis_clark.screens.explore import ExploreScreen
from lewis_clark.screens.title import TitleScreen
from lewis_clark.state import GameState
from lewis_clark.textures import generate_all as generate_textures

# Ctrl+Shift+1 … 5 — window presets when drag-resize fails (e.g. WSL / remote desktop).
_WINDOW_PRESETS = (
    (2100, 1350),
    (1400, 900),
    (1600, 900),
    (1920, 1080),
    (1280, 720),
)


class AppScene(Enum):
    TITLE = auto()
    CINEMATIC = auto()
    EXPLORE = auto()  # walking the current Region
    EXPEDITION = auto()  # Expedition Map: route overview and Legs


class Transition:
    """Fade-to-black / iris-wipe transition between scenes."""

    DURATION = 30

    def __init__(self):
        self.active = False
        self._frame = 0
        self._phase = "out"
        self._callback = None
        self._black = None

    def start(self, callback):
        self.active = True
        self._frame = 0
        self._phase = "out"
        self._callback = callback

    def draw(self, surf):
        if not self.active:
            return
        if self._black is None or self._black.get_size() != (assets.SW, assets.SH):
            self._black = pygame.Surface(
                (assets.SW, assets.SH),
                pygame.SRCALPHA,
            )

        self._frame += 1
        half = self.DURATION // 2

        if self._phase == "out":
            t = min(1.0, self._frame / half)
            alpha = int(t * 255)
            if self._frame >= half:
                self._phase = "in"
                self._frame = 0
                if self._callback:
                    self._callback()
                    self._callback = None
        else:
            t = min(1.0, self._frame / half)
            alpha = int((1.0 - t) * 255)
            if self._frame >= half:
                self.active = False
                return

        self._black.fill((0, 0, 0, alpha))
        surf.blit(self._black, (0, 0))


class App:
    def __init__(self):
        self.scene = AppScene.TITLE
        self.title = TitleScreen(self._start_cinematic, self._load_game)
        self.cinematic = None
        self.state = None
        self.explore = None
        self.expedition = None
        self._transition = Transition()
        self.input = InputState()
        self.input.init_controllers()
        self._running = True

    def _maybe_resize_with_keyboard(self, event: pygame.event.Event) -> None:
        """Keyboard window sizing for hosts where mouse resize does not reach SDL (WSLg, RDP, etc.)."""
        mods = pygame.key.get_mods()
        if not (mods & pygame.KMOD_CTRL and mods & pygame.KMOD_SHIFT):
            return
        k = event.key
        if pygame.K_1 <= k <= pygame.K_5:
            i = k - pygame.K_1
            if i < len(_WINDOW_PRESETS):
                self._apply_window_resize(*_WINDOW_PRESETS[i])
            return
        if k in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
            self._apply_window_resize(int(assets.SW * 1.08), int(assets.SH * 1.08))
            return
        if k in (pygame.K_MINUS, pygame.K_KP_MINUS):
            self._apply_window_resize(int(assets.SW / 1.08), int(assets.SH / 1.08))

    def _apply_window_resize(self, nw: int, nh: int) -> None:
        """Resize drawable surface, fonts, textures, and active screen layouts."""
        nw = max(960, min(int(nw), 4096))
        nh = max(540, min(int(nh), 2160))
        if (nw, nh) == (assets.SW, assets.SH):
            return
        assets.SW, assets.SH = nw, nh
        assets.screen = pygame.display.set_mode((nw, nh), pygame.RESIZABLE)
        surf = pygame.display.get_surface()
        if surf is not None:
            assets.SW, assets.SH = surf.get_size()
        load_fonts(assets)
        generate_textures()
        self._transition._black = None
        if self.scene == AppScene.TITLE:
            self.title.on_resize()
        elif self.scene == AppScene.CINEMATIC and self.cinematic:
            self.cinematic.on_resize()
        if self.explore:
            self.explore.on_resize()
        if self.expedition:
            self.expedition.on_resize()

    def _start_cinematic(self):
        def switch():
            self.cinematic = CinematicScreen(self._start_game)
            self.scene = AppScene.CINEMATIC

        self._transition.start(switch)

    def _start_game(self, state=None):
        def switch():
            st = state or GameState()
            if not state:
                st.add_journal(
                    "We set out from Camp Dubois. The Corps of Discovery \u2014 33 strong \u2014 begins its great journey."
                )
                st.add_journal(
                    "York and Drouillard march with us. Sacagawea will join at Fort Mandan."
                )
            self.state = st
            self._enter_region()

        self._transition.start(switch)

    def _enter_region(self):
        """Build the current Region's world and put the Corps on the ground in it."""
        world = build_world(self.state.current_region)
        self.explore = ExploreScreen(
            self.state, world, self._open_map, self._new_game, self._field_interact, self.input
        )
        self.expedition = None
        self.scene = AppScene.EXPLORE

    def _open_map(self, mode=VIEW):
        if not self.state:
            return
        self.expedition = ExpeditionMapScreen(
            self.state, mode, self._open_field, self._take_leg, self._save_game, self.input
        )
        self.scene = AppScene.EXPEDITION

    def _quit(self):
        self._running = False

    def _open_field(self):
        if self.explore:
            self.scene = AppScene.EXPLORE

    def _take_leg(self, option):
        legs.take_leg(self.state, option)
        self._transition.start(self._enter_region)

    def _field_interact(self, kind: str, data: dict) -> None:
        """Resolve an on-the-ground interaction against the shared GameState."""
        s = self.state
        if not s:
            return
        if kind == "landmark":
            if data["id"] not in s.landmarks_visited:
                s.landmarks_visited.append(data["id"])
                if "waypoint" in data:
                    s.current_wp = max(s.current_wp, int(data["waypoint"]))
                s.add_journal(f"{data['name']} — {data.get('desc', '')}".rstrip(" —"))
        elif kind == "hunt":
            s.food = min(100, s.food + 12)
            s.morale = min(100, s.morale + 2)
            s.add_journal("The hunting party brings back fresh game. (+12 food)")
            s.clamp()
        elif kind == "depart":
            self._open_map(DEPART)

    def _dispatch(self, event, actions):
        """Send one event (and its actions) to the scene active when it arrived.

        The scene is captured up front so an action that switches scenes (M on
        the map opening the field) is never re-delivered to the new scene.
        """
        scene = self.scene
        if scene == AppScene.TITLE:
            self.title.handle(event, self._start_cinematic, self._load_game)
            for a in actions:
                self.title.handle_action(a, self._start_cinematic, self._quit)
        elif scene == AppScene.CINEMATIC and self.cinematic:
            self.cinematic.handle(event)
            for a in actions:
                self.cinematic.handle_action(a)
        elif scene == AppScene.EXPEDITION and self.expedition:
            self.expedition.handle(event)
            for a in actions:
                self.expedition.handle_action(a)
        elif scene == AppScene.EXPLORE and self.explore:
            for a in actions:
                self.explore.handle_action(a)

    def _new_game(self):
        def switch():
            self.scene = AppScene.TITLE
            self.title = TitleScreen(self._start_cinematic, self._load_game)

        self._transition.start(switch)

    def _save_game(self):
        if not self.state:
            return
        save_expedition_json(self.state.to_dict())

    def _load_game(self):
        data = load_expedition_json()
        if data:
            self._start_game(state=GameState.from_dict(data))

    def run(self):
        while self._running:
            assets.clock.tick(assets.FPS)
            # Some platforms (incl. some Windows/SDL builds) omit VIDEORESIZE; sync from surface.
            surf = pygame.display.get_surface()
            if surf is not None:
                cw, ch = surf.get_size()
                if (cw, ch) != (assets.SW, assets.SH):
                    self._apply_window_resize(cw, ch)

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self._running = False
                if event.type == pygame.VIDEORESIZE:
                    w = getattr(event, "w", None) or event.size[0]
                    h = getattr(event, "h", None) or event.size[1]
                    self._apply_window_resize(w, h)
                if event.type == pygame.KEYDOWN:
                    self._maybe_resize_with_keyboard(event)

                # Held state must track every event, even mid-transition.
                actions = self.input.handle_event(event)
                if not self._transition.active:
                    self._dispatch(event, actions)

            if (
                self.scene == AppScene.EXPLORE
                and self.explore
                and not self._transition.active
            ):
                self.explore.update()

            assets.screen.fill(assets.UI_BG)
            if self.scene == AppScene.TITLE:
                self.title.draw(assets.screen)
            elif self.scene == AppScene.CINEMATIC and self.cinematic:
                self.cinematic.draw(assets.screen)
            elif self.scene == AppScene.EXPEDITION and self.expedition:
                self.expedition.draw(assets.screen)
            elif self.scene == AppScene.EXPLORE and self.explore:
                self.explore.draw(assets.screen)

            vignette = getattr(assets, "TEX_VIGNETTE", None)
            if vignette:
                assets.screen.blit(vignette, (0, 0))

            self._transition.draw(assets.screen)

            pygame.display.flip()

        pygame.quit()
        sys.exit()
