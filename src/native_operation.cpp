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
#include <QRegularExpression>
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
    appState.setOperation(action);
    appState.setResult(i18n("Working… Authentication may be required. See the console for progress."), appState.hostStatus());
    if (action == u"rollback"_s)
        appState.setRollbackRunning(true);
    else
        appState.setUpdateRunning(true);
    auto onFinish = [console, result, resultCount, action, callback](int code) {
        const bool success = code == 0 && *resultCount == 1 && validNativeResult(*result, action);
        if (success) {
            appState.setResult(resultText(*result), result->value(u"status"_s).toObject());
        } else {
            const auto message = code == 0
                ? i18n("The command returned no valid, verified deployment result. Refresh status before taking further action.")
                : i18n("The operation failed or monitoring was interrupted. Deployment state is unverified; inspect the console and refresh status.");
            appState.setResult(message);
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
    auto line = [console, result, resultCount](QString text, Console::LogLevel level) {
        const QString prefix = u"FE_XICO_RESULT "_s;
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
