// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

#include "preview_tour.h"
#include "utils.h"

#include <KColorSchemeManager>

#include <QApplication>
#include <QDir>
#include <QFont>
#include <QImage>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

#include <functional>
#include <iostream>
#include <memory>

using namespace Qt::Literals::StringLiterals;

namespace
{

struct Scenario {
    QString name;
    int page; // index into Main.qml smokeTestPage()
    QSize size;
    std::function<void()> setup;
};

// Example deployment entries. Values are illustrative and the digests are
// visibly placeholders; the window footer labels every image as simulated.
QJsonObject imageEntry(const QString &version, const QString &timestamp, const QString &digest)
{
    return QJsonObject{
        {u"image"_s, QJsonObject{
            {u"image"_s, QJsonObject{{u"image"_s, u"ghcr.io/royoshi/fe-xicoos:latest"_s}, {u"transport"_s, u"registry"_s}}},
            {u"version"_s, version},
            {u"timestamp"_s, timestamp},
            {u"imageDigest"_s, digest},
        }},
        {u"pinned"_s, false},
    };
}

QJsonObject current()
{
    return imageEntry(u"45.20261102.0"_s, u"2026-11-02T06:10:00Z"_s, u"sha256:preview-current-image"_s);
}

QJsonObject previous()
{
    return imageEntry(u"44.20261030.0"_s, u"2026-10-30T06:05:00Z"_s, u"sha256:preview-previous-image"_s);
}

QJsonObject newer()
{
    return imageEntry(u"45.20261104.0"_s, u"2026-11-04T06:12:00Z"_s, u"sha256:preview-newer-image"_s);
}

QJsonObject host(QJsonObject booted, const QJsonValue &staged, const QJsonValue &rollback, bool rollbackQueued = false)
{
    return QJsonObject{
        {u"apiVersion"_s, u"org.containers.bootc/v1"_s},
        {u"spec"_s, QJsonObject{{u"bootOrder"_s, rollbackQueued ? u"rollback"_s : u"default"_s}}},
        {u"status"_s, QJsonObject{
            {u"booted"_s, booted},
            {u"staged"_s, staged},
            {u"rollback"_s, rollback},
            {u"rollbackQueued"_s, rollbackQueued},
        }},
    };
}

QJsonObject withCachedUpdate()
{
    auto booted = current();
    booted.insert(u"cachedUpdate"_s, newer().value(u"image"_s));
    return host(booted, QJsonValue::Null, previous());
}

void reset()
{
    appState.setUpdateRunning(false);
    appState.setRollbackRunning(false);
    appState.setCommandSucceeded(false);
    appState.clearOutcome();
    appState.setOperation({});
    appState.setResult({});
}

void finished(const QString &action, const QString &outcome, const QString &message, const QJsonObject &hostStatus)
{
    appState.setResult(message, hostStatus);
    appState.recordOutcome(action, true, outcome);
    appState.setCommandSucceeded(true);
}

void running(const QString &action, const QJsonObject &hostStatus = {})
{
    appState.setOperation(action);
    appState.setResult(u"Working… Authentication may be required. See the console for progress."_s, hostStatus);
    if (action == u"rollback"_s)
        appState.setRollbackRunning(true);
    else
        appState.setUpdateRunning(true);
}

QList<Scenario> scenarios()
{
    const QSize normal(1100, 820);
    const auto plain = host(current(), QJsonValue::Null, previous());
    const auto staged = host(current(), newer(), previous());
    const auto rollbackQueued = host(current(), QJsonValue::Null, previous(), true);

    return {
        {u"01-dashboard-not-read"_s, 0, normal, [] {}},
        {u"02-dashboard-reading"_s, 0, normal, [] { running(u"status"_s); }},
        {u"03-dashboard-status-read"_s, 0, normal, [plain] {
            finished(u"status"_s, u"status"_s, u"Deployment status refreshed. No deployment is pending for the next boot."_s, plain);
        }},
        {u"04-dashboard-checking"_s, 0, normal, [plain] {
            finished(u"status"_s, u"status"_s, u"Deployment status refreshed."_s, plain);
            running(u"check"_s, plain);
        }},
        {u"05-dashboard-update-available"_s, 0, normal, [] {
            finished(u"check"_s, u"update-available"_s, u"An OS image update is available. Select Update FE-Xico to stage it."_s, withCachedUpdate());
        }},
        {u"06-dashboard-updating"_s, 0, normal, [] {
            finished(u"check"_s, u"update-available"_s, u"An OS image update is available."_s, withCachedUpdate());
            running(u"upgrade"_s, withCachedUpdate());
        }},
        {u"07-dashboard-staged"_s, 0, normal, [staged] {
            finished(u"upgrade"_s, u"staged"_s, u"A new FE-XicoOS deployment is staged. Restart when you are ready."_s, staged);
        }},
        {u"08-dashboard-up-to-date"_s, 0, normal, [plain] {
            finished(u"check"_s, u"up-to-date"_s, u"No newer OS deployment was staged. The configured image is up to date."_s, plain);
        }},
        {u"09-dashboard-failed"_s, 0, normal, [] {
            appState.setResult(u"The operation failed or monitoring was interrupted. Deployment state is unverified; inspect the console and refresh status."_s);
            appState.recordOutcome(u"upgrade"_s, false);
        }},
        {u"10-dashboard-rollback-staged"_s, 0, normal, [rollbackQueued] {
            finished(u"rollback"_s, u"rollback-queued"_s, u"The previous deployment is queued for the next boot. Restart when ready."_s, rollbackQueued);
        }},
        {u"11-deployments"_s, 1, normal, [plain] {
            finished(u"status"_s, u"status"_s, u"Deployment status refreshed."_s, plain);
        }},
        {u"12-deployments-rollback-queued"_s, 1, normal, [rollbackQueued] {
            finished(u"rollback"_s, u"rollback-queued"_s, u"The previous deployment is queued for the next boot."_s, rollbackQueued);
        }},
        {u"13-settings"_s, 2, normal, [] {}},
        {u"14-dashboard-small-window"_s, 0, QSize(380, 700), [] {
            finished(u"check"_s, u"update-available"_s, u"An OS image update is available."_s, withCachedUpdate());
        }},
        {u"15-dashboard-large-window"_s, 0, QSize(1920, 1080), [] {
            finished(u"check"_s, u"update-available"_s, u"An OS image update is available."_s, withCachedUpdate());
        }},
    };
}

} // namespace

void preparePreviewAppearance()
{
    const QString scheme = qEnvironmentVariable("FE_XICO_PREVIEW_COLOR_SCHEME", u"BreezeDark"_s);
    KColorSchemeManager::instance()->activateSchemeId(scheme);
    const QString family = qEnvironmentVariable("FE_XICO_PREVIEW_FONT");
    if (!family.isEmpty()) {
        QFont font(family, 10);
        QApplication::setFont(font);
    }
}

void runPreviewTour(QQmlApplicationEngine *engine, const QString &outputDir)
{
    auto *window = qobject_cast<QQuickWindow *>(engine->rootObjects().value(0));
    if (!window || !QDir().mkpath(outputDir)) {
        std::cerr << "Preview tour: no window or output directory." << std::endl;
        QTimer::singleShot(0, qApp, [] { QCoreApplication::exit(EXIT_FAILURE); });
        return;
    }

    auto list = std::make_shared<QList<Scenario>>(scenarios());
    auto index = std::make_shared<qsizetype>(0);
    auto failures = std::make_shared<int>(0);
    auto step = std::make_shared<std::function<void()>>();

    *step = [window, outputDir, list, index, failures, step]() {
        if (*index >= list->size()) {
            reset();
            QCoreApplication::exit(*failures ? EXIT_FAILURE : EXIT_SUCCESS);
            return;
        }
        const Scenario scenario = list->at(*index);
        reset();
        scenario.setup();
        window->resize(scenario.size);
        QVariant placed;
        if (!QMetaObject::invokeMethod(window, "smokeTestPage", Q_RETURN_ARG(QVariant, placed), Q_ARG(QVariant, scenario.page))
            || !placed.toBool())
            ++*failures;
        // Let layout, bindings and the short state transition settle.
        QTimer::singleShot(900, window, [window, outputDir, scenario, index, failures, step]() {
            const QImage image = window->grabWindow();
            const QString path = QDir(outputDir).filePath(scenario.name + u".png"_s);
            if (image.isNull() || !image.save(path)) {
                ++*failures;
                std::cerr << "Preview tour: could not save " << path.toStdString() << std::endl;
            } else {
                std::cout << "Preview tour: " << path.toStdString() << std::endl;
            }
            ++*index;
            (*step)();
        });
    };
    QTimer::singleShot(800, window, [step]() { (*step)(); });
}
