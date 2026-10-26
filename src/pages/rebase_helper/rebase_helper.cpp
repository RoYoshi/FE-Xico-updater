// SPDX-License-Identifier: GPL-2.0-or-later
#include "rebase_helper.h"
#include "k_config.h"
#include "native_operation.h"

RebaseHelperBackend::RebaseHelperBackend(QObject *parent) : QObject(parent)
{
    m_console = new Console::Model(this);
}

void RebaseHelperBackend::rollbackImage(QJSValue callback)
{
    runNativeOperation(m_console, configIni.getValue(u"Commands"_s, u"systemRollbackCommand"_s), u"rollback"_s, callback);
}

void RebaseHelperBackend::refreshStatus(QJSValue callback)
{
    runNativeOperation(m_console, configIni.getValue(u"Commands"_s, u"systemStatusCommand"_s), u"status"_s, callback);
}
