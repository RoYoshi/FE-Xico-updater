// SPDX-License-Identifier: GPL-2.0-or-later
#include "auto_update_settings.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <KLocalizedString>

namespace {
const QString timer = QStringLiteral("fe-xicoos-auto-update.timer");
const QString helper = QStringLiteral("/usr/libexec/fe-xicoos-auto-update-control");
const QString settings = QStringLiteral("/var/lib/fe-xicoos-auto-updates/settings.json");
}

AutoUpdateSettings::AutoUpdateSettings(QObject *parent) : QObject(parent)
{
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::finished, this, &AutoUpdateSettings::processFinished);
    connect(&m_process, &QProcess::errorOccurred, this, &AutoUpdateSettings::processFailed);
}

QString AutoUpdateSettings::statusText() const
{
    if (busy()) return i18n("Reading or changing automatic OS update settings…");
    if (!m_available) return i18n("Safe automatic updates are not available in this FE-XicoOS image.");
    return m_enabled ? i18n("Automatic OS updates enabled (no automatic restart)")
                     : i18n("Automatic OS updates disabled");
}

void AutoUpdateSettings::loadHours()
{
    m_startHour = 9;
    m_endHour = 23;
    QFile file(settings);
    if (!file.exists()) return; // Built-in FE-XicoOS defaults, matching the worker.
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = i18n("Could not read active-hour settings.");
        return;
    }
    QJsonParseError parseError;
    const auto doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    const auto obj = doc.object();
    const auto start = obj.value(QStringLiteral("active_start"));
    const auto end = obj.value(QStringLiteral("active_end"));
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()
        || !start.isDouble() || !end.isDouble()
        || start.toDouble() != start.toInt() || end.toDouble() != end.toInt()
        || start.toInt() < 0 || start.toInt() > 23 || end.toInt() < 0 || end.toInt() > 23) {
        m_error = i18n("Invalid active-hour settings on disk. The defaults are displayed.");
        return;
    }
    m_startHour = start.toInt();
    m_endHour = end.toInt();
}

void AutoUpdateSettings::refresh()
{
    if (busy()) return;
    m_error.clear();
    loadHours();
    m_operation = Operation::Read;
    Q_EMIT stateChanged();
    m_process.start(QStringLiteral("/usr/bin/systemctl"),
                    {QStringLiteral("is-enabled"), timer});
}

void AutoUpdateSettings::startChange(const QStringList &arguments)
{
    if (busy() || !m_available) return;
    if (!QFileInfo::exists(helper) || !QFileInfo::exists(QStringLiteral("/usr/bin/pkexec"))) {
        m_error = i18n("This FE-XicoOS image lacks the authenticated auto-update helper.");
        Q_EMIT stateChanged();
        return;
    }
    m_error.clear();
    m_operation = Operation::Change;
    Q_EMIT stateChanged();
    // Fixed helper subcommands and validated integers. Never elevate the GUI.
    QStringList argv{QStringLiteral("--disable-internal-agent"),
                     QStringLiteral("/usr/bin/bash"), helper};
    argv.append(arguments);
    m_process.start(QStringLiteral("/usr/bin/pkexec"), argv);
}

void AutoUpdateSettings::setAutoUpdatesEnabled(bool enabled)
{
    if (busy() || !m_available || enabled == m_enabled) return;
    startChange({enabled ? QStringLiteral("enable") : QStringLiteral("disable")});
}

void AutoUpdateSettings::setActiveHours(int startHour, int endHour)
{
    if (busy() || !m_available || startHour < 0 || startHour > 23
        || endHour < 0 || endHour > 23
        || (startHour == m_startHour && endHour == m_endHour)) return;
    startChange({QStringLiteral("hours"), QString::number(startHour), QString::number(endHour)});
}

void AutoUpdateSettings::processFinished(int exitCode, QProcess::ExitStatus status)
{
    const auto completed = m_operation;
    const QString response = QString::fromUtf8(m_process.readAllStandardOutput()).trimmed();
    m_operation = Operation::None;
    if (completed == Operation::Read) {
        m_state = response.section(QLatin1Char('\n'), 0, 0).trimmed();
        m_available = (m_state == QLatin1String("enabled") ||
                       m_state == QLatin1String("enabled-runtime") ||
                       m_state == QLatin1String("disabled") ||
                       m_state == QLatin1String("masked") ||
                       m_state == QLatin1String("masked-runtime"));
        m_enabled = m_state == QLatin1String("enabled") ||
                    m_state == QLatin1String("enabled-runtime");
        if (status != QProcess::NormalExit || !m_available)
            m_error = i18n("Cannot read the FE-XicoOS update timer state: %1", response);
    } else if (completed == Operation::Change) {
        if (exitCode != 0 || status != QProcess::NormalExit)
            m_error = i18n("Update settings were not changed (authentication cancelled or service error). %1", response);
        else
            m_error.clear();
        // Read the real systemd and on-disk state; never trust the clicked UI.
        const QString changeError = m_error;
        Q_EMIT stateChanged();
        refresh();
        if (!changeError.isEmpty()) {
            m_error = changeError; // Keep authentication failures visible.
            Q_EMIT stateChanged();
        }
        return;
    }
    Q_EMIT stateChanged();
}

void AutoUpdateSettings::processFailed(QProcess::ProcessError error)
{
    if (error != QProcess::FailedToStart) return;
    m_operation = Operation::None;
    m_available = false;
    m_error = i18n("Could not start systemd or the authorization helper.");
    Q_EMIT stateChanged();
}

#include "moc_auto_update_settings.cpp"
