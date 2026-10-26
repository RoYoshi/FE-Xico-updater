// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QJsonObject>
#include <QJSValue>
#include <QString>
#include "console.h"

// Validate a versioned result independently of process exit status.
bool validNativeResult(const QJsonObject &result, const QString &action);
void runNativeOperation(Console::Model *console, const QString &command, const QString &action, QJSValue callback);
