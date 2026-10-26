// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QQmlEngine>
#include <QJSValue>
#include "console.h"

// Historical type name retained to preserve frontend navigation and imports.
class RebaseHelperBackend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(Console::Model *consoleModel MEMBER m_console CONSTANT)
public:
    explicit RebaseHelperBackend(QObject *parent = nullptr);
    Q_INVOKABLE void rollbackImage(QJSValue callback);
    Q_INVOKABLE void refreshStatus(QJSValue callback);
    Console::Model *m_console;
};
