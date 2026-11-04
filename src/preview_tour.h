// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>

class QQmlApplicationEngine;

// Design-review previews for CI (--render-previews DIR).
//
// Sets AppState to example states through its ordinary setters, renders the
// real QML pages and saves one PNG per state. Every image carries the window's
// "Simulated preview" footer. No process, bootc call or privileged action is
// ever started, and nothing is written outside DIR.

// Optional appearance for the tour, from FE_XICO_PREVIEW_COLOR_SCHEME
// (default BreezeDark) and FE_XICO_PREVIEW_FONT (e.g. "Terminus").
void preparePreviewAppearance();

void runPreviewTour(QQmlApplicationEngine *engine, const QString &outputDir);
