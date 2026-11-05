// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QJsonObject>
#include <QJSValue>
#include <QString>
#include <QVariantMap>
#include "console.h"

// Validate a versioned result independently of process exit status.
bool validNativeResult(const QJsonObject &result, const QString &action);
// Display data for one FE_XICO_PROGRESS record from the FE-XicoOS backend,
// which relays bootc's own `--progress-fd` events. Empty when the record is
// malformed or belongs to another action. Numbers are bootc's, never derived:
// "known" is true only when bootc gave a total that the value does not exceed.
QVariantMap describeNativeProgress(const QJsonObject &record, const QString &action);
void runNativeOperation(Console::Model *console, const QString &command, const QString &action, QJSValue callback);
