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


class App:
    def __init__(self):
        self.scene = AppScene.TITLE
        self.title = TitleScreen(self._start_cinematic, self._load_game)
        self.cinematic = None
        self.game_screen = None

    def _start_cinematic(self):
        self.cinematic = CinematicScreen(self._start_game)
        self.scene = AppScene.CINEMATIC

    def _start_game(self, state=None):
        st = state or GameState()
        if not state:
            st.add_journal(
                "We set out from Camp Dubois. The Corps of Discovery — 33 strong — begins its great journey."
            )
            st.add_journal(
                "York and Drouillard march with us. Sacagawea will join at Fort Mandan."
            )
        self.game_screen = GameScreen(st, self._new_game)
        self.scene = AppScene.GAME

    def _new_game(self):
        self.scene = AppScene.TITLE
        self.title = TitleScreen(self._start_cinematic, self._load_game)

    def _save_game(self):
        if not self.game_screen:
            return
        save_expedition_json(self.game_screen.state.to_dict())

    def _load_game(self):
        data = load_expedition_json()
        if data:
            self._start_game(state=GameState.from_dict(data))

    def run(self):
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

            pygame.display.flip()

        pygame.quit()
        sys.exit()
