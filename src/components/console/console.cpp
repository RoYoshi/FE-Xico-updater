// SPDX-FileCopyrightText: 2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "console.h"
#include <array>
#include <memory>
#include "utils.h"
#include <qcontainerfwd.h>
#include <qobject.h>
#include <qprocess.h>

using namespace Console;

int Model::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    else
        return m_lines.size();
}

QVariant Model::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_lines.size())
        return QVariant();

    const Line &line = m_lines.at(index.row());

    switch (role) {
    case Qt::DisplayRole:
        return line.content;

    case Qt::DecorationRole:
        return QVariant::fromValue(line.level);

    default:
        return QVariant();
    }
}

void Model::newLine(const QString &content, LogLevel level)
{
    if (m_lines.size() >= 2000) {
        beginRemoveRows(QModelIndex(), 0, 499);
        m_lines.remove(0, 500);
        endRemoveRows();
    }
    const int row = m_lines.size();
    beginInsertRows(QModelIndex(), row, row);
    m_lines.append({content.size() > 8192 ? content.left(8192) + u" … [line truncated; see system journal for full output]"_s : content, level});
    endInsertRows();
}

void Model::copyToClipboard() const
{
    QString plainText;

    for (int row = 0; row < rowCount(); ++row) {
        plainText += data(index(row, 0), Qt::DisplayRole).toString() + QStringLiteral("\n");
    }

    if (!plainText.isEmpty())
        QApplication::clipboard()->setText(plainText);
}

void Model::runProcess(QStringList process,
                       function<void(int)> onFinish,
                       function<void(QProcess::ProcessError)> onError,
                       function<void(QString, LogLevel)> lineFormatter)
{
    auto *command = new QProcess(this);
    auto done = std::make_shared<bool>(false);
    auto failed = std::make_shared<bool>(false);
    auto buffers = std::make_shared<std::array<QByteArray, 2>>();
    auto lineHandler = lineFormatter ? lineFormatter : [this](QString text, LogLevel level) {
        newLine(text, level);
    };
    auto drain = [command, buffers, lineHandler](bool final) {
        (*buffers)[0] += command->readAllStandardOutput();
        (*buffers)[1] += command->readAllStandardError();
        for (size_t i = 0; i < buffers->size(); ++i) {
            auto &buffer = (*buffers)[i];
            const auto level = i == 0 ? LogLevel::Info : LogLevel::Error;
            qsizetype end;
            while ((end = buffer.indexOf('\n')) >= 0) {
                lineHandler(QString::fromUtf8(buffer.left(end)), level);
                buffer.remove(0, end + 1);
            }
            // Bound malformed/no-newline streams; flush final diagnostics too.
            if ((final || buffer.size() > 1024 * 1024) && !buffer.isEmpty()) {
                lineHandler(QString::fromUtf8(buffer), level);
                buffer.clear();
            }
        }
    };
    auto finish = [this, command, done, drain, onFinish](int code) {
        if (*done)
            return;
        *done = true;
        drain(true);
        newLine(u"Command finished with exit code %1"_s.arg(code), code == 0 ? LogLevel::Info : LogLevel::Error);
        command->deleteLater();
        if (onFinish)
            onFinish(code);
    };
    connect(command, &QProcess::readyReadStandardOutput, this, [drain]() { drain(false); });
    connect(command, &QProcess::readyReadStandardError, this, [drain]() { drain(false); });
    connect(command, &QProcess::finished, this, [finish, failed](int code, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit && !*failed ? code : -1);
    });
    connect(command, &QProcess::errorOccurred, this, [this, command, failed, finish, onError](QProcess::ProcessError error) {
        *failed = true;
        newLine(command->errorString(), LogLevel::Error);
        if (onError)
            onError(error); // Diagnostic only; terminal callback is always onFinish.
        if (error == QProcess::FailedToStart)
            finish(-1); // Qt does not emit finished for FailedToStart.
    });
    connect(command, &QProcess::started, this, [command]() { command->closeWriteChannel(); });
    if (process.isEmpty() || process.first().trimmed().isEmpty()) {
        newLine(u"No command configured."_s, LogLevel::Error);
        QTimer::singleShot(0, this, [finish]() { finish(-1); });
        return;
    }
    newLine(u"> "_s + process.join(u' '), LogLevel::Info);
    command->start(process.first(), process.mid(1));
}
