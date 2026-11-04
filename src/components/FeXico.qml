// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later
pragma Singleton

import QtQuick
import org.kde.kirigami as Kirigami

// FE-XicoOS design tokens, kept in one place.
//
// Surfaces always come from the active KDE colour scheme (FE-XicoOS ships a
// near-black one), so the updater stays legible with any scheme. FE-Xico's
// green, magenta and silver are accents only. On light schemes the accents
// switch to darker forms that keep readable contrast.
QtObject {
    // Brand accents.
    readonly property color green: "#00FF00"
    readonly property color magenta: "#FF00FF"
    readonly property color silver: "#C0C0C0"

    // Darker forms for text and lines on light colour schemes.
    readonly property color greenOnLight: "#00782A"
    readonly property color magentaOnLight: "#A0008C"
    readonly property color silverOnLight: "#5F6368"

    // Structure.
    readonly property int hairline: 1
    readonly property int accentEdge: 3

    function isDark(background) {
        return Kirigami.ColorUtils.brightnessForColor(background) === Kirigami.ColorUtils.Dark;
    }

    // Identity, progress and primary interaction.
    function accent(background) {
        return isDark(background) ? green : greenOnLight;
    }

    // Restrained secondary accent: selection and navigation details.
    function secondary(background) {
        return isDark(background) ? magenta : magentaOnLight;
    }

    // Outlines, labels and secondary information.
    function structure(background) {
        return isDark(background) ? silver : silverOnLight;
    }

    // A raised surface: the background lifted slightly towards the text colour
    // (charcoal on near-black, light grey on white).
    function surface(theme) {
        return Kirigami.ColorUtils.tintWithAlpha(theme.backgroundColor, theme.textColor, 0.045);
    }

    function outline(theme) {
        return Kirigami.ColorUtils.tintWithAlpha(theme.backgroundColor, structure(theme.backgroundColor), 0.45);
    }

    // tone: "positive" | "active" | "attention" | "negative" | "neutral".
    // Warnings and errors keep KDE's own semantic colours.
    function toneColor(tone, theme) {
        switch (tone) {
        case "positive":
        case "active":
            return accent(theme.backgroundColor);
        case "attention":
            return theme.neutralTextColor;
        case "negative":
            return theme.negativeTextColor;
        default:
            return structure(theme.backgroundColor);
        }
    }

    // FE-XicoOS defaults to the bitmap Terminus font, which suits body text
    // but not large, scaled headings. Use the scalable Hack face (shipped by
    // FE-XicoOS) for headings in that case; otherwise keep the user's font.
    function headingFamily(defaultFamily) {
        return /terminus/i.test(defaultFamily) ? "Hack" : defaultFamily;
    }

    // Short transitions only, and none when KDE animations are turned off
    // (Kirigami then reports durations of 0 or 1 ms).
    function motion(duration) {
        return Kirigami.Units.longDuration > 1 ? duration : 0;
    }
}
