/*
 *  SPDX-FileCopyrightText: 2021 Felipe Kinoshita <kinofhek@gmail.com>
 *  SPDX-FileCopyrightText: 2022 Nate Graham <nate@kde.org>
 *  SPDX-FileCopyrightText: 2024 Oliver Beard <olib141@outlook.com>
 *  SPDX-FileCopyrightText: 2025 Robert French <frenchrobertm@outlook.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

#include <QApplication>
#include <QClipboard>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>

#include <KLocalizedString>

#include "console.h"
#include "k_config.h"
#include "system_update.h"
#include "utils.h"
#include "native_operation.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QtDebug>
#include <qcontainerfwd.h>
#include <qfuture.h>
#include <qjsondocument.h>
#include <qjsvalue.h>
#include <qlogging.h>
#include <qnumeric.h>
#include <qobject.h>
#include <qprocess.h>
#include <qstringview.h>

using namespace Qt::Literals::StringLiterals;

SystemUpdateBackend::SystemUpdateBackend(QObject *parent)
    : QObject(parent)
{
    m_console = new Console::Model(this);
}

void SystemUpdateBackend::runUpdate(QJSValue callback)
{
    runNativeOperation(m_console, configIni.getValue(u"Commands"_s, u"systemUpdateCommand"_s), u"upgrade"_s, callback);
}

void SystemUpdateBackend::checkUpdates(QJSValue callback)
{
    runNativeOperation(m_console, configIni.getValue(u"Commands"_s, u"systemCheckCommand"_s), u"check"_s, callback);
}

void SystemUpdateBackend::refreshStatus(QJSValue callback)
{
    runNativeOperation(m_console, configIni.getValue(u"Commands"_s, u"systemStatusCommand"_s), u"status"_s, callback);
}

void SystemUpdateBackend::setProgressLevel(int progressLevel)
{
    m_progressLevel = progressLevel;
    Q_EMIT progressLevelChanged();
}

void SystemUpdateBackend::setBlockUpdate(bool updateError)
{
    m_blockUpdate = updateError;
    Q_EMIT blockUpdateChanged();
}

#include "moc_system_update.cpp"
