// SPDX-License-Identifier: GPL-2.0-or-later
#include "auto_update_settings.h"

#include <QFileInfo>
#include <KLocalizedString>

namespace {
const QString timer = QStringLiteral("bootc-fetch-apply-updates.timer");
const QString helper = QStringLiteral("/usr/libexec/fe-xicoos-auto-update-control");
}

AutoUpdateSettings::AutoUpdateSettings(QObject *parent) : QObject(parent)
{
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::finished, this, &AutoUpdateSettings::processFinished);
    connect(&m_process, &QProcess::errorOccurred, this, &AutoUpdateSettings::processFailed);
}

QString AutoUpdateSettings::statusText() const
{
    if (busy()) return i18n("Checking automatic OS updates…");
    if (!m_available) return i18n("Automatic OS updates are unavailable on this installation.");
    return m_enabled ? i18n("Automatic OS updates enabled") :
                       i18n("Automatic OS updates disabled");
}

void AutoUpdateSettings::refresh()
{
    if (busy()) return;
    m_operation = Operation::Read;
    Q_EMIT stateChanged();
    m_process.start(QStringLiteral("/usr/bin/systemctl"),
                    {QStringLiteral("is-enabled"), timer});
}

void AutoUpdateSettings::setAutoUpdatesEnabled(bool enabled)
{
    if (busy() || !m_available || enabled == m_enabled) return;
    if (!QFileInfo::exists(helper) || !QFileInfo::exists(QStringLiteral("/usr/bin/pkexec"))) {
        m_error = i18n("This FE-XicoOS image lacks the authenticated auto-update helper.");
        Q_EMIT stateChanged();
        return;
    }

    m_error.clear();
    m_requested = enabled;
    m_operation = Operation::Change;
    Q_EMIT stateChanged();
    // Never run shell command strings or elevate the GUI. This fixed helper
    // validates only enable/disable; Polkit prompts for admin authorization.
    m_process.start(QStringLiteral("/usr/bin/pkexec"),
                    {QStringLiteral("/usr/bin/bash"), helper,
                     enabled ? QStringLiteral("enable") : QStringLiteral("disable")});
}

void AutoUpdateSettings::processFinished(int exitCode, QProcess::ExitStatus status)
{
    const auto completed = m_operation;
    const QString response = QString::fromUtf8(m_process.readAllStandardOutput()).trimmed();
    m_operation = Operation::None;
    if (completed == Operation::Read) {
        // is-enabled returns nonzero for both disabled and masked; stdout is
        // the authoritative state, not the QProcess return code.
        m_state = response.section(QLatin1Char('\n'), 0, 0).trimmed();
        m_available = (m_state == QLatin1String("enabled") ||
                       m_state == QLatin1String("enabled-runtime") ||
                       m_state == QLatin1String("disabled") ||
                       m_state == QLatin1String("masked") ||
                       m_state == QLatin1String("masked-runtime"));
        m_enabled = m_state == QLatin1String("enabled") ||
                    m_state == QLatin1String("enabled-runtime");
        if (status != QProcess::NormalExit || !m_available)
            m_error = i18n("Cannot read the bootc update timer state: %1", response);
    } else if (completed == Operation::Change) {
        if (exitCode != 0 || status != QProcess::NormalExit)
            m_error = i18n("Automatic update setting was not changed. Authentication may have been cancelled, or systemd reported an error. %1", response);
        else
            m_error.clear();
        Q_EMIT stateChanged();
        refresh();  // Actual state always wins over the requested checkbox.
        return;
    }
    Q_EMIT stateChanged();
}

void AutoUpdateSettings::processFailed(QProcess::ProcessError error)
{
    if (error != QProcess::FailedToStart) return;
    m_operation = Operation::None;
    m_available = false;
    m_error = i18n("Could not start the systemd or authorization helper.");
    Q_EMIT stateChanged();
}

#include "moc_auto_update_settings.cpp"
