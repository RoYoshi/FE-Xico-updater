// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_operation.h"
#include "utils.h"
#include <KLocalizedString>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QGuiApplication>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonArray>
#include <QLocale>
#include <QRegularExpression>
#include <cmath>
#include <memory>

bool validNativeResult(const QJsonObject &r, const QString &action)
{
    const QMap<QString, QStringList> outcomes = {
        {u"status"_s, {u"status"_s}},
        {u"check"_s, {u"update-available"_s, u"up-to-date"_s, u"already-staged"_s, u"download-only"_s}},
        {u"upgrade"_s, {u"staged"_s, u"already-staged"_s, u"up-to-date"_s, u"download-only"_s}},
        {u"rollback"_s, {u"rollback-queued"_s, u"rollback-already-queued"_s}},
    };
    const auto outcome = r.value(u"outcome"_s).toString();
    const auto host = r.value(u"status"_s).toObject();
    const auto status = host.value(u"status"_s).toObject();
    const auto spec = host.value(u"spec"_s).toObject();
    const auto staged = status.value(u"staged"_s);
    const auto downloadOnly = staged.toObject().value(u"downloadOnly"_s);
    const bool locked = downloadOnly.toBool();
    const auto rollback = status.value(u"rollback"_s);
    const auto queued = status.value(u"rollbackQueued"_s);
    static const QRegularExpression id(u"^[0-9a-f]{32}$"_s);
    if (r.value(u"protocol"_s).toInt() != 1 || r.value(u"action"_s).toString() != action
        || !outcomes.value(action).contains(outcome)
        || !id.match(r.value(u"invocation"_s).toString()).hasMatch()
        || r.value(u"started"_s).toString().toULongLong() == 0
        || host.value(u"apiVersion"_s).toString() != u"org.containers.bootc/v1"_s
        || !status.value(u"booted"_s).isObject() || !queued.isBool()
        || !(staged.isNull() || staged.isObject()) || !(rollback.isNull() || rollback.isObject())
        || (!downloadOnly.isUndefined() && !downloadOnly.isBool())
        || !r.value(u"rebootRequired"_s).isBool())
        return false;
    const auto order = spec.value(u"bootOrder"_s).toString();
    if ((order != u"default"_s && order != u"rollback"_s)
        || (order == u"rollback"_s) != queued.toBool()
        || (queued.toBool() && (!rollback.isObject() || staged.isObject()))
        || r.value(u"rebootRequired"_s).toBool() != ((staged.isObject() && !locked) || queued.toBool()))
        return false;
    if (outcome == u"staged"_s || outcome == u"already-staged"_s)
        return staged.isObject() && !locked && !queued.toBool();
    if (outcome == u"download-only"_s)
        return staged.isObject() && locked && !queued.toBool();
    if (action == u"rollback"_s)
        return queued.toBool();
    if (outcome == u"up-to-date"_s || outcome == u"update-available"_s)
        return !staged.isObject() && !queued.toBool();
    return true;
}

// An unsigned integer as bootc writes it (JSON numbers arrive as doubles).
static bool progressCount(const QJsonValue &value, double *out)
{
    if (!value.isDouble())
        return false;
    const double number = value.toDouble();
    if (!(number >= 0) || number > 9007199254740992.0 || std::floor(number) != number)
        return false;
    *out = number;
    return true;
}

static QString stagingStepText(const QString &subtask, const QString &bootcDescription)
{
    if (subtask == u"merging"_s)
        return i18n("Merging the new image");
    if (subtask == u"bound_images"_s)
        return i18n("Pulling bound images");
    if (subtask == u"deploying"_s)
        return i18n("Writing the new deployment");
    if (subtask == u"cleanup"_s)
        return i18n("Removing old images");
    return bootcDescription; // a step this updater does not know: bootc's own words
}

QVariantMap describeNativeProgress(const QJsonObject &record, const QString &action)
{
    static const QStringList states = {u"waiting"_s, u"reporting"_s, u"unsupported"_s, u"incompatible"_s};
    const auto state = record.value(u"state"_s).toString();
    double seq = 0;
    if (record.value(u"protocol"_s) != QJsonValue(1) || record.value(u"action"_s).toString() != action
        || !progressCount(record.value(u"seq"_s), &seq) || seq < 1 || !states.contains(state))
        return {};
    QVariantMap out{{u"seq"_s, seq}, {u"state"_s, state}, {u"known"_s, false}, {u"value"_s, 0.0}, {u"total"_s, 0.0},
                    {u"headline"_s, QString()}, {u"detail"_s, QString()}, {u"task"_s, QString()}};
    if (state == u"waiting"_s) {
        out[u"headline"_s] = i18n("Starting the update");
        out[u"detail"_s] = i18n("Waiting for bootc to report progress.");
        return out;
    }
    if (state == u"unsupported"_s) {
        out[u"detail"_s] = i18n("This system's bootc does not report progress. The update is running, and the result appears when it finishes.");
        return out;
    }
    if (state == u"incompatible"_s) {
        out[u"detail"_s] = i18n("bootc reports progress in a format this updater does not know. The update is running, and the result appears when it finishes.");
        return out;
    }

    const auto event = record.value(u"event"_s).toObject();
    const auto type = event.value(u"type"_s).toString();
    double steps = 0, stepsTotal = 0, bytes = 0, bytesTotal = 0;
    if ((type != u"ProgressBytes"_s && type != u"ProgressSteps"_s) || !event.value(u"task"_s).isString()
        || !event.value(u"description"_s).isString() || !event.value(u"subtasks"_s).isArray()
        || !progressCount(event.value(u"steps"_s), &steps) || !progressCount(event.value(u"stepsTotal"_s), &stepsTotal)
        || (type == u"ProgressBytes"_s
            && (!progressCount(event.value(u"bytes"_s), &bytes) || !progressCount(event.value(u"bytesTotal"_s), &bytesTotal))))
        return {};
    const auto task = event.value(u"task"_s).toString();
    const auto description = event.value(u"description"_s).toString();
    out[u"task"_s] = task;
    if (task == u"pulling"_s)
        out[u"headline"_s] = i18n("Downloading the update");
    else if (task == u"importing"_s)
        out[u"headline"_s] = i18n("Importing the update");
    else if (task == u"staging"_s)
        out[u"headline"_s] = i18n("Deploying the update");
    else
        out[u"headline"_s] = description; // a stage this updater does not know: bootc's own words

    QStringList detail;
    if (type == u"ProgressBytes"_s) {
        const QLocale locale;
        if (bytesTotal > 0 && bytes <= bytesTotal) {
            out[u"known"_s] = true;
            out[u"value"_s] = bytes;
            out[u"total"_s] = bytesTotal;
            detail << i18nc("downloaded of total, e.g. 412 MB of 1.2 GB", "%1 of %2",
                            locale.formattedDataSize(qint64(bytes)), locale.formattedDataSize(qint64(bytesTotal)));
        } else if (bytes > 0) {
            detail << i18n("%1 downloaded", locale.formattedDataSize(qint64(bytes)));
        }
        if (stepsTotal > 0 && steps <= stepsTotal)
            detail << i18nc("container image layers fetched of layers to fetch", "layer %1 of %2", qint64(steps), qint64(stepsTotal));
    } else {
        // A single step (importing) has no intermediate position to show.
        if (stepsTotal >= 2 && steps <= stepsTotal) {
            out[u"known"_s] = true;
            out[u"value"_s] = steps;
            out[u"total"_s] = stepsTotal;
            detail << i18n("step %1 of %2", qint64(steps), qint64(stepsTotal));
        }
        const auto subtasks = event.value(u"subtasks"_s).toArray();
        for (qsizetype i = subtasks.size() - 1; i >= 0; --i) {
            const auto sub = subtasks.at(i).toObject();
            if (sub.value(u"completed"_s) == QJsonValue(false)) {
                detail << stagingStepText(sub.value(u"subtask"_s).toString(), sub.value(u"description"_s).toString());
                break;
            }
        }
    }
    out[u"detail"_s] = detail.join(u" · "_s);
    return out;
}

static QString resultText(const QJsonObject &result)
{
    const auto outcome = result.value(u"outcome"_s).toString();
    if (result.value(u"status"_s).toObject().value(u"status"_s).toObject().value(u"staged"_s).toObject().value(u"downloadOnly"_s).toBool())
        return i18n("A download-only deployment is preserved and locked. Reboot will not apply it. This updater does not unlock downloaded deployments.");
    if (outcome == u"staged"_s)
        return i18n("A new FE-XicoOS deployment is staged. Restart when you are ready.");
    if (outcome == u"already-staged"_s)
        return i18n("A deployment was already staged. It has been preserved; restart when ready.");
    if (outcome == u"rollback-queued"_s || outcome == u"rollback-already-queued"_s)
        return i18n("The previous deployment is queued for the next boot. Restart when ready.");
    if (outcome == u"update-available"_s)
        return i18n("An OS image update is available. Select Update FE-Xico to stage it.");
    if (outcome == u"up-to-date"_s)
        return i18n("No newer OS deployment was staged. The configured image is up to date.");
    return result.value(u"rebootRequired"_s).toBool()
        ? i18n("A deployment is pending for the next boot. Review Deployments & Recovery.")
        : i18n("Deployment status refreshed. No deployment is pending for the next boot.");
}

// Plasma desktop notifications for checks that complete with the updater
// minimized or inactive. The foreground uses its normal Kirigami feedback.
static void notifyBackgroundCheck(bool success, const QJsonObject &result)
{
    if (QGuiApplication::applicationState() == Qt::ApplicationActive)
        return;
    QString title;
    QString body;
    if (!success) {
        title = i18n("FE-XicoOS update check failed");
        body = i18n("An OS update check encountered an error. Open FE-Xico Updater for details.");
    } else {
        const auto outcome = result.value(u"outcome"_s).toString();
        if (outcome == u"up-to-date"_s) {
            title = i18n("No FE-XicoOS updates");
            body = i18n("Your OS image is up to date.");
        } else if (outcome == u"update-available"_s) {
            title = i18n("FE-XicoOS update available");
            body = i18n("A new OS image is available. Open FE-Xico Updater to stage it.");
        } else if (outcome == u"already-staged"_s) {
            title = i18n("FE-XicoOS update ready");
            body = i18n("An update is staged. Restart when you are ready.");
        } else if (outcome == u"download-only"_s) {
            title = i18n("FE-XicoOS download preserved");
            body = i18n("A locked download-only deployment exists. Review it manually.");
        } else {
            title = i18n("FE-XicoOS update check completed");
            body = resultText(result);
        }
    }
    if (!QDBusConnection::sessionBus().isConnected())
        return;
    auto message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("Notify"));
    message.setArguments({
        QStringLiteral("FE-Xico Updater"), uint(0),
        QStringLiteral("system-software-update"), title, body,
        QStringList{}, QVariantMap{}, int(10000)});
    QDBusConnection::sessionBus().asyncCall(message);
}

void runNativeOperation(Console::Model *console, const QString &command, const QString &action, QJSValue callback)
{
    if (!appState.allowCommands()) {
        console->newLine(i18n("Another operation is running."), Console::LogLevel::Error);
        if (callback.isCallable())
            callback.call({1});
        return;
    }
    auto result = std::make_shared<QJsonObject>();
    auto resultCount = std::make_shared<int>(0);
    appState.setCommandSucceeded(false);
    appState.clearProgress();
    appState.setOperation(action);
    appState.setResult(i18n("Working… Authentication may be required. See the console for progress."), appState.hostStatus());
    if (action == u"rollback"_s)
        appState.setRollbackRunning(true);
    else
        appState.setUpdateRunning(true);
    auto onFinish = [console, result, resultCount, action, callback](int code) {
        const bool success = code == 0 && *resultCount == 1 && validNativeResult(*result, action);
        // Progress ends with the operation; the verified result replaces it.
        appState.clearProgress();
        if (success) {
            appState.setResult(resultText(*result), result->value(u"status"_s).toObject());
            appState.recordOutcome(action, true, result->value(u"outcome"_s).toString());
        } else {
            const auto message = code == 0
                ? i18n("The command returned no valid, verified deployment result. Refresh status before taking further action.")
                : i18n("The operation failed or monitoring was interrupted. Deployment state is unverified; inspect the console and refresh status.");
            appState.setResult(message);
            appState.recordOutcome(action, false);
            console->newLine(message, Console::LogLevel::Error);
        }
        appState.setCommandSucceeded(success);
        if (action == u"check"_s)
            notifyBackgroundCheck(success, *result);
        if (action == u"rollback"_s)
            appState.setRollbackRunning(false);
        else
            appState.setUpdateRunning(false);
        // QML observes the final state before it receives completion.
        if (callback.isCallable())
            callback.call({success ? 0 : 1});
    };
    auto line = [console, result, resultCount, action](QString text, Console::LogLevel level) {
        const QString prefix = u"FE_XICO_RESULT "_s;
        const QString progressPrefix = u"FE_XICO_PROGRESS "_s;
        if (level == Console::LogLevel::Info && text.startsWith(progressPrefix)) {
            // Display only. A record that does not validate is dropped silently.
            const auto progress = describeNativeProgress(
                QJsonDocument::fromJson(text.mid(progressPrefix.size()).toUtf8()).object(), action);
            if (!progress.isEmpty() && appState.commandRunning())
                appState.setProgress(progress);
            return;
        }
        if (level == Console::LogLevel::Info && text.startsWith(prefix)) {
            ++*resultCount;
            *result = QJsonDocument::fromJson(text.mid(prefix.size()).toUtf8()).object();
            return;
        }
        if (!text.trimmed().isEmpty())
            console->newLine(text, level);
    };
    console->runProcess(QProcess::splitCommand(command), onFinish, nullptr, line);
}
