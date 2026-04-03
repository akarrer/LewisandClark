"""Application loop and scene switching."""

from __future__ import annotations

import sys
from enum import Enum, auto

import pygame

from lewis_clark import assets
from lewis_clark.save_load import load_expedition_json, save_expedition_json
from lewis_clark.screens.cinematic import CinematicScreen
from lewis_clark.screens.game import GameScreen
from lewis_clark.screens.title import TitleScreen
from lewis_clark.state import GameState


class AppScene(Enum):
    TITLE = auto()
    CINEMATIC = auto()
    GAME = auto()


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
        if self._black is None:
            self._black = pygame.Surface(
                (assets.SW, assets.SH), pygame.SRCALPHA,
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
        self.game_screen = None
        self._transition = Transition()

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
            self.game_screen = GameScreen(st, self._new_game)
            self.scene = AppScene.GAME
        self._transition.start(switch)

    def _new_game(self):
        def switch():
            self.scene = AppScene.TITLE
            self.title = TitleScreen(self._start_cinematic, self._load_game)
        self._transition.start(switch)

    def _save_game(self):
        if not self.game_screen:
            return
        save_expedition_json(self.game_screen.state.to_dict())

    def _load_game(self):
        data = load_expedition_json()
        if data:
            self._start_game(state=GameState.from_dict(data))

    def run(self):
        vignette = getattr(assets, "TEX_VIGNETTE", None)

        running = True
        while running:
            assets.clock.tick(assets.FPS)
            events = pygame.event.get()
            for event in events:
                if event.type == pygame.QUIT:
                    running = False
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    if self.scene == AppScene.GAME:
                        self._new_game()
                    else:
                        running = False

                if not self._transition.active:
                    if self.scene == AppScene.TITLE:
                        self.title.handle(event, self._start_cinematic, self._load_game)
                    elif self.scene == AppScene.CINEMATIC and self.cinematic:
                        self.cinematic.handle(event)
                    elif self.scene == AppScene.GAME and self.game_screen:
                        self.game_screen.handle(
                            event, self._new_game, self._save_game, self._load_game
                        )

            assets.screen.fill(assets.UI_BG)
            if self.scene == AppScene.TITLE:
                self.title.draw(assets.screen)
            elif self.scene == AppScene.CINEMATIC and self.cinematic:
                self.cinematic.draw(assets.screen)
            elif self.scene == AppScene.GAME and self.game_screen:
                self.game_screen.draw(assets.screen)

            if vignette:
                assets.screen.blit(vignette, (0, 0))

            self._transition.draw(assets.screen)

            pygame.display.flip()

        pygame.quit()
        sys.exit()
