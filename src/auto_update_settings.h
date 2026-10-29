// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QProcess>
#include <QQmlEngine>
#include <QString>

// Reads the real FE-XicoOS timer and root-owned active-hour configuration.
class AutoUpdateSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(int startHour READ startHour NOTIFY stateChanged)
    Q_PROPERTY(int endHour READ endHour NOTIFY stateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY stateChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY stateChanged)

public:
    explicit AutoUpdateSettings(QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    bool available() const { return m_available; }
    bool busy() const { return m_operation != Operation::None; }
    int startHour() const { return m_startHour; }
    int endHour() const { return m_endHour; }
    QString statusText() const;
    QString errorText() const { return m_error; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setAutoUpdatesEnabled(bool enabled);
    Q_INVOKABLE void setActiveHours(int startHour, int endHour);

Q_SIGNALS:
    void stateChanged();

private:
    enum class Operation { None, Read, Change };
    void processFinished(int exitCode, QProcess::ExitStatus status);
    void processFailed(QProcess::ProcessError error);
    void loadHours();
    void startChange(const QStringList &arguments);

    QProcess m_process;
    Operation m_operation = Operation::None;
    bool m_enabled = false;
    bool m_available = false;
    int m_startHour = 9;
    int m_endHour = 23;
    QString m_error;
    QString m_state;
};
