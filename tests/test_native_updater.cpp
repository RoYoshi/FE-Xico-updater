// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtTest>
#include <QJSEngine>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QRegularExpression>
#include "console.h"
#include "native_operation.h"
#include "utils.h"
#include "k_config.h"
#include <QTemporaryDir>
#include <QFile>

class NativeUpdaterTest : public QObject
{
    Q_OBJECT
    QStringList args(const QString &mode) { return {QStringLiteral(PYTHON_PATH), QStringLiteral(FIXTURE_PATH), mode}; }
    QString command(const QString &mode, const QString &action = u"upgrade"_s) {
        return u"\""_s + QStringLiteral(PYTHON_PATH) + u"\" \""_s + QStringLiteral(FIXTURE_PATH) + u"\" "_s + mode + u" "_s + action;
    }
    QString output(Console::Model &model) {
        QString result;
        for (int i = 0; i < model.rowCount(); ++i)
            result += model.data(model.index(i, 0)).toString() + u'\n';
        return result;
    }
private Q_SLOTS:
    void init() {
        appState.setUpdateRunning(false);
        appState.setRollbackRunning(false);
        appState.setCommandSucceeded(false);
        appState.setResult({});
        appState.clearOutcome();
        appState.clearProgress();
    }
    void processCompletion_data() {
        QTest::addColumn<QString>("mode"); QTest::addColumn<int>("expected");
        QTest::newRow("normal") << u"empty"_s << 0;
        QTest::newRow("failure") << u"fail"_s << 19;
        QTest::newRow("crash") << u"crash"_s << -1;
    }
    void processCompletion() {
        QFETCH(QString, mode); QFETCH(int, expected);
        Console::Model model; int calls = 0, code = 123;
        model.runProcess(args(mode), [&](int c) { ++calls; code = c; });
        QTRY_COMPARE(calls, 1); QCOMPARE(code, expected); QTest::qWait(50); QCOMPARE(calls, 1);
    }
    void failedToStartAndEmpty() {
        for (const QStringList &command : {QStringList{}, QStringList{u"/does-not-exist-fe-xico"_s}}) {
            Console::Model model; int calls = 0;
            model.runProcess(command, [&](int c) { QVERIFY(c != 0); ++calls; });
            QTRY_COMPARE(calls, 1); QTest::qWait(50); QCOMPARE(calls, 1);
        }
    }
    void optionalCallbacks() {
        Console::Model model;
        model.runProcess(args(u"empty"_s)); model.runProcess({u"/does-not-exist-fe-xico"_s});
        QTest::qWait(100); // Previously unconditionally called empty std::function.
    }
    void partialOutputAndArguments() {
        Console::Model model; bool done = false;
        model.runProcess(args(u"partial"_s), [&](int) { done = true; });
        QTRY_VERIFY(done); QVERIFY(output(model).contains(u"final stdout"_s)); QVERIFY(output(model).contains(u"final stderr"_s));
        done = false;
        auto list = args(u"args"_s); list << u"one argument"_s << u"; echo INJECTED"_s << u"$(id)"_s;
        QString captured;
        model.runProcess(list, [&](int c) { QCOMPARE(c, 0); done = true; }, nullptr,
                         [&](QString line, Console::LogLevel) { captured += line; });
        QTRY_VERIFY(done);
        const auto parsed = QJsonDocument::fromJson(captured.toUtf8()).array();
        QCOMPARE(parsed.at(0).toString(), u"one argument"_s);
        QCOMPARE(parsed.at(1).toString(), u"; echo INJECTED"_s);
        QCOMPARE(parsed.at(2).toString(), u"$(id)"_s);
    }
    void longProcessResponsive() {
        Console::Model model; bool done = false; int ticks = 0;
        QTimer timer; timer.setInterval(10); connect(&timer, &QTimer::timeout, [&] { ++ticks; }); timer.start();
        model.runProcess(args(u"long"_s), [&](int c) { QCOMPARE(c, 0); done = true; });
        QTRY_VERIFY(output(model).contains(u"started"_s)); QVERIFY(!done);
        QTRY_VERIFY(done); QVERIFY(ticks > 5);
    }
    void nativeOutcomes_data() {
        QTest::addColumn<QString>("mode"); QTest::addColumn<QString>("action");
        QTest::addColumn<bool>("success"); QTest::addColumn<bool>("reboot");
        QTest::newRow("download-only") << u"download-only"_s << u"upgrade"_s << true << false;
        QTest::newRow("download-only-status") << u"download-only"_s << u"status"_s << true << false;
        QTest::newRow("download-only-check") << u"download-only"_s << u"check"_s << true << false;
        QTest::newRow("staged") << u"staged"_s << u"upgrade"_s << true << true;
        QTest::newRow("no-op") << u"noop"_s << u"upgrade"_s << true << false;
        QTest::newRow("check") << u"noop"_s << u"check"_s << true << false;
        QTest::newRow("rollback") << u"noop"_s << u"rollback"_s << true << true;
        for (const auto &mode : {u"locked-lie"_s, u"locked-mislabeled"_s, u"invalid-lock"_s, u"fail"_s, u"empty"_s, u"malformed"_s, u"duplicate"_s, u"contradiction"_s,
                                 u"nonzero-result"_s, u"stderr-result"_s, u"crash"_s})
            QTest::newRow(qPrintable(mode)) << mode << u"upgrade"_s << false << false;
        QTest::newRow("rollback-failure") << u"fail"_s << u"rollback"_s << false << false;
    }
    void nativeOutcomes() {
        QFETCH(QString, mode); QFETCH(QString, action); QFETCH(bool, success); QFETCH(bool, reboot);
        Console::Model model; QJSEngine engine;
        QQmlEngine::setObjectOwnership(&appState, QQmlEngine::CppOwnership);
        engine.globalObject().setProperty(u"state"_s, engine.newQObject(&appState));
        engine.evaluate(u"var calls=0; var code=-100; var wasRunning=true; function completed(c) { calls++; code=c; wasRunning=state.commandRunning; }"_s);
        runNativeOperation(&model, command(mode, action), action, engine.globalObject().property(u"completed"_s));
        QVERIFY(appState.commandRunning());
        QTRY_COMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
        QCOMPARE(engine.globalObject().property(u"code"_s).toInt(), success ? 0 : 1);
        QVERIFY(!engine.globalObject().property(u"wasRunning"_s).toBool());
        QCOMPARE(appState.commandSucceeded(), success); QCOMPARE(appState.rebootRequired(), reboot);
        if (mode == u"download-only"_s) {
            QVERIFY(appState.resultMessage().contains(u"Reboot will not apply"_s));
            QVERIFY(!appState.rebootRequired());
        }
        // The dashboard's verified outcome and check time follow the result.
        if (success) {
            QVERIFY(!appState.outcome().isEmpty());
            QVERIFY(appState.outcome() != u"failed"_s);
            if (action == u"check"_s || action == u"upgrade"_s) {
                QVERIFY(appState.lastCheckedAt().isValid());
                QCOMPARE(appState.lastCheckOutcome(), appState.outcome());
            } else {
                QVERIFY(!appState.lastCheckedAt().isValid());
                QVERIFY(appState.lastCheckOutcome().isEmpty());
            }
        } else {
            QCOMPARE(appState.outcome(), u"failed"_s);
            QVERIFY(!appState.lastCheckedAt().isValid());
            QVERIFY(appState.hostStatus().isEmpty());
        }
        QVERIFY(appState.allowCommands()); QTest::qWait(30);
        QCOMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
    }
    QJsonObject progressRecord(const QJsonValue &event, const QString &state = u"reporting"_s, double seq = 4,
                               const QString &action = u"upgrade"_s) {
        return QJsonObject{{u"protocol"_s, 1}, {u"action"_s, action}, {u"invocation"_s, QString(32, u'a')}, {u"seq"_s, seq},
                           {u"state"_s, state}, {u"bootcProtocol"_s, u"0.1.0"_s}, {u"event"_s, event}, {u"ignored"_s, 0}};
    }
    QJsonObject pulling(double bytes, double bytesTotal, double steps = 1, double stepsTotal = 4) {
        return QJsonObject{{u"type"_s, u"ProgressBytes"_s}, {u"task"_s, u"pulling"_s}, {u"description"_s, u"Pulling Image: x"_s},
                           {u"id"_s, u"x"_s}, {u"bytesCached"_s, 0}, {u"bytes"_s, bytes}, {u"bytesTotal"_s, bytesTotal},
                           {u"stepsCached"_s, 0}, {u"steps"_s, steps}, {u"stepsTotal"_s, stepsTotal}, {u"subtasks"_s, QJsonArray{}}};
    }
    QJsonObject stepsEvent(const QString &task, double steps, double stepsTotal, const QJsonArray &subtasks = {}) {
        return QJsonObject{{u"type"_s, u"ProgressSteps"_s}, {u"task"_s, task}, {u"description"_s, u"bootc words"_s}, {u"id"_s, u"x"_s},
                           {u"stepsCached"_s, 0}, {u"steps"_s, steps}, {u"stepsTotal"_s, stepsTotal}, {u"subtasks"_s, subtasks}};
    }
    void progressRecords() {
        // Bytes with a total: determinate, bootc's own numbers.
        auto p = describeNativeProgress(progressRecord(pulling(50, 200)), u"upgrade"_s);
        QVERIFY(p.value(u"known"_s).toBool());
        QCOMPARE(p.value(u"value"_s).toDouble(), 50.0); QCOMPARE(p.value(u"total"_s).toDouble(), 200.0);
        QVERIFY(p.value(u"detail"_s).toString().contains(u"layer 1 of 4"_s));
        // A total of 0 means "unspecified"; a value past its total is not shown as a fraction.
        for (const auto &event : {pulling(50, 0), pulling(300, 200)}) {
            p = describeNativeProgress(progressRecord(event), u"upgrade"_s);
            QVERIFY(!p.isEmpty()); QVERIFY(!p.value(u"known"_s).toBool());
        }
        // Importing is one step: nothing to show between start and end.
        p = describeNativeProgress(progressRecord(stepsEvent(u"importing"_s, 0, 1)), u"upgrade"_s);
        QVERIFY(!p.value(u"known"_s).toBool()); QCOMPARE(p.value(u"task"_s).toString(), u"importing"_s);
        // Staging: steps from bootc, and the step still running.
        const QJsonArray subs{QJsonObject{{u"subtask"_s, u"merging"_s}, {u"description"_s, u"Merging Image"_s}, {u"id"_s, u"merging"_s}, {u"completed"_s, true}},
                              QJsonObject{{u"subtask"_s, u"deploying"_s}, {u"description"_s, u"Deploying Image"_s}, {u"id"_s, u"deploying"_s}, {u"completed"_s, false}}};
        p = describeNativeProgress(progressRecord(stepsEvent(u"staging"_s, 1, 3, subs)), u"upgrade"_s);
        QVERIFY(p.value(u"known"_s).toBool()); QCOMPARE(p.value(u"value"_s).toDouble(), 1.0); QCOMPARE(p.value(u"total"_s).toDouble(), 3.0);
        QVERIFY(p.value(u"detail"_s).toString().contains(u"Writing the new deployment"_s));
        // An unknown stage keeps bootc's own description.
        p = describeNativeProgress(progressRecord(stepsEvent(u"verifying"_s, 0, 1)), u"upgrade"_s);
        QCOMPARE(p.value(u"headline"_s).toString(), u"bootc words"_s);
        // States without numbers.
        for (const auto &state : {u"waiting"_s, u"unsupported"_s, u"incompatible"_s}) {
            p = describeNativeProgress(progressRecord(QJsonValue::Null, state), u"upgrade"_s);
            QCOMPARE(p.value(u"state"_s).toString(), state); QVERIFY(!p.value(u"known"_s).toBool());
            QVERIFY(!p.value(u"detail"_s).toString().isEmpty());
        }
        // Anything malformed is dropped.
        auto bad = progressRecord(pulling(50, 200)); bad[u"protocol"_s] = 2;
        QVERIFY(describeNativeProgress(bad, u"upgrade"_s).isEmpty());
        QVERIFY(describeNativeProgress(progressRecord(pulling(50, 200)), u"rollback"_s).isEmpty());
        QVERIFY(describeNativeProgress(progressRecord(pulling(50, 200), u"reporting"_s, 0), u"upgrade"_s).isEmpty());
        QVERIFY(describeNativeProgress(progressRecord(pulling(50, 200), u"guessing"_s), u"upgrade"_s).isEmpty());
        for (const auto &value : {QJsonValue(-1), QJsonValue(1.5), QJsonValue(true), QJsonValue(u"50"_s), QJsonValue(1e300)}) {
            auto event = pulling(50, 200); event[u"bytes"_s] = value;
            QVERIFY(describeNativeProgress(progressRecord(event), u"upgrade"_s).isEmpty());
        }
        auto missing = pulling(50, 200); missing.remove(u"bytesTotal"_s);
        QVERIFY(describeNativeProgress(progressRecord(missing), u"upgrade"_s).isEmpty());
        QVERIFY(describeNativeProgress(progressRecord(QJsonObject{{u"type"_s, u"Start"_s}}), u"upgrade"_s).isEmpty());
    }
    void progressDuringOperation() {
        for (const auto &mode : {u"progress"_s, u"progress-fail"_s}) {
            Console::Model model; QJSEngine engine;
            engine.evaluate(u"var calls=0; var code=-1; function completed(c) { calls++; code=c; }"_s);
            QStringList seen; QList<double> seqs;
            auto connection = connect(&appState, &SingletonInternals::AppState::progressChanged, this, [&] {
                const auto p = appState.progress();
                if (!p.isEmpty()) { seen << p.value(u"state"_s).toString(); seqs << p.value(u"seq"_s).toDouble(); }
            });
            runNativeOperation(&model, command(mode, u"upgrade"_s), u"upgrade"_s, engine.globalObject().property(u"completed"_s));
            QTRY_COMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
            disconnect(connection);
            // Each new record once, in order; the stale repeat and the broken line are ignored.
            QCOMPARE(seen, (QStringList{u"waiting"_s, u"reporting"_s, u"reporting"_s}));
            QCOMPARE(seqs, (QList<double>{1, 2, 3}));
            // The verified result alone decides; progress is gone afterwards.
            const bool ok = mode == u"progress"_s;
            QCOMPARE(engine.globalObject().property(u"code"_s).toInt(), ok ? 0 : 1);
            QCOMPARE(appState.commandSucceeded(), ok);
            QCOMPARE(appState.outcome(), ok ? u"staged"_s : u"failed"_s);
            QVERIFY(appState.progress().isEmpty());
            QVERIFY(!output(model).contains(u"FE_XICO_PROGRESS"_s));
        }
    }
    void failedCheckKeepsPreviousCheckTime() {
        Console::Model model; QJSEngine engine;
        engine.evaluate(u"var calls=0; function completed(c) { calls++; }"_s);
        runNativeOperation(&model, command(u"noop"_s, u"check"_s), u"check"_s, engine.globalObject().property(u"completed"_s));
        QTRY_COMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
        const auto checkedAt = appState.lastCheckedAt();
        QVERIFY(checkedAt.isValid());
        runNativeOperation(&model, command(u"fail"_s, u"check"_s), u"check"_s, engine.globalObject().property(u"completed"_s));
        QTRY_COMPARE(engine.globalObject().property(u"calls"_s).toInt(), 2);
        QCOMPARE(appState.outcome(), u"failed"_s);
        QCOMPARE(appState.lastCheckedAt(), checkedAt);
    }
    void dashboardStates() {
        // Evaluate the production derivation (status.js) without a GUI.
        QFile file(QStringLiteral(SOURCE_PATH) + u"/pages/system_update/status.js"_s);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QString source = QString::fromUtf8(file.readAll());
        source.replace(u".pragma library"_s, QString());
        QJSEngine engine;
        QVERIFY(!engine.evaluate(source).isError());
        auto state = [&](const QString &facts) {
            const auto value = engine.evaluate(u"dashboardState("_s + facts + u")"_s);
            return value.isError() ? u"error"_s : value.toString();
        };
        auto action = [&](const QString &s) { return engine.evaluate(u"primaryAction('"_s + s + u"')"_s).toString(); };
        const QString booted = u"{image:{imageDigest:'sha256:a'}}"_s;
        const QString host = u"{status:{booted:"_s + booted + u",staged:null,rollback:null,rollbackQueued:false}}"_s;
        // Nothing read: never "up to date", even with a stale check outcome.
        QCOMPARE(state(u"{host:{}}"_s), u"unknown"_s);
        QCOMPARE(state(u"{host:{},lastCheckOutcome:'up-to-date'}"_s), u"unknown"_s);
        QCOMPARE(action(u"unknown"_s), u"check"_s);
        // Status read without a check is not "up to date".
        QCOMPARE(state(u"{outcome:'status',host:"_s + host + u"}"_s), u"unchecked"_s);
        QCOMPARE(state(u"{outcome:'status',lastCheckOutcome:'up-to-date',host:"_s + host + u"}"_s), u"up-to-date"_s);
        // A cached newer digest wins over an older "up to date" check.
        const QString cached = u"{status:{booted:{image:{imageDigest:'sha256:a'},cachedUpdate:{imageDigest:'sha256:b'}},staged:null,rollback:null,rollbackQueued:false}}"_s;
        QCOMPARE(state(u"{lastCheckOutcome:'up-to-date',host:"_s + cached + u"}"_s), u"update-available"_s);
        QCOMPARE(action(u"update-available"_s), u"update"_s);
        const QString same = u"{status:{booted:{image:{imageDigest:'sha256:a'},cachedUpdate:{imageDigest:'sha256:a'}},staged:null,rollback:null,rollbackQueued:false}}"_s;
        QCOMPARE(state(u"{host:"_s + same + u"}"_s), u"unchecked"_s);
        // Pending deployments.
        const QString staged = u"{status:{booted:"_s + booted + u",staged:{image:{}},rollback:null,rollbackQueued:false}}"_s;
        QCOMPARE(state(u"{host:"_s + staged + u"}"_s), u"staged"_s);
        QCOMPARE(action(u"staged"_s), u"restart"_s);
        const QString locked = u"{status:{booted:"_s + booted + u",staged:{downloadOnly:true},rollback:null,rollbackQueued:false}}"_s;
        QCOMPARE(state(u"{host:"_s + locked + u"}"_s), u"download-only"_s);
        QCOMPARE(action(u"download-only"_s), u"review-deployments"_s);
        const QString queued = u"{status:{booted:"_s + booted + u",staged:null,rollback:{},rollbackQueued:true}}"_s;
        QCOMPARE(state(u"{host:"_s + queued + u"}"_s), u"rollback-staged"_s);
        QCOMPARE(action(u"rollback-staged"_s), u"restart"_s);
        // Running operations and failures.
        QCOMPARE(state(u"{updateRunning:true,operation:'check',host:"_s + host + u"}"_s), u"checking"_s);
        QCOMPARE(state(u"{updateRunning:true,operation:'upgrade',host:"_s + host + u"}"_s), u"updating"_s);
        QCOMPARE(state(u"{updateRunning:true,operation:'status',host:{}}"_s), u"reading"_s);
        QCOMPARE(state(u"{rollbackRunning:true,host:"_s + host + u"}"_s), u"rolling-back"_s);
        QCOMPARE(action(u"checking"_s), u"progress"_s);
        QCOMPARE(state(u"{outcome:'failed',lastCheckOutcome:'up-to-date',host:{}}"_s), u"failed"_s);
        QCOMPARE(action(u"failed"_s), u"review-error"_s);
        QCOMPARE(engine.evaluate(u"tone('up-to-date')"_s).toString(), u"positive"_s);
        QCOMPARE(engine.evaluate(u"tone('failed')"_s).toString(), u"negative"_s);
        QCOMPARE(engine.evaluate(u"tone('staged')"_s).toString(), u"attention"_s);
    }
    void actualControllerRouting() {
        QJSEngine engine;
        // Evaluate the production event handlers with inert UI objects: no SDL
        // device, process launch or privileged command is involved.
        auto handler = [&](const QString &path, const QString &name) {
            QFile file(QStringLiteral(SOURCE_PATH) + path);
            if (!file.open(QIODevice::ReadOnly)) return QString();
            const QString text = QString::fromUtf8(file.readAll());
            const auto start = text.indexOf(u"function "_s + name + u"("_s);
            const auto brace = text.indexOf(u'{', start);
            int depth = 1; qsizetype end = brace + 1;
            while (end < text.size() && depth) {
                if (text[end] == u'{') ++depth;
                if (text[end] == u'}') --depth;
                ++end;
            }
            return start < 0 || depth ? QString() : text.mid(start, end - start);
        };
        const auto page = handler(u"/pages/system_update/SystemUpdate.qml"_s, u"handleInput"_s);
        const auto main = handler(u"/pages/Main.qml"_s, u"onButtonEvent"_s);
        QVERIFY(!page.isEmpty()); QVERIFY(!main.isEmpty());
        QVERIFY(!engine.evaluate(page + u"; var pageHandler=handleInput;"_s + main).isError());
        QVERIFY(!engine.evaluate(u"var updates=0,consoleEvents=0,dialogEvents=0,drawerEvents=0; "
            "var mainAction={enabled:true,trigger:function(){updates++}}; "
            "var consoleDrawer={drawerOpen:false,handleInput:function(){consoleEvents++}}; "
            "var globalDrawer={drawerOpen:false,handleInput:function(){drawerEvents++}}; "
            "var root={activeDialog:null,pageStack:{currentItem:{handleInput:pageHandler}}};"_s).isError());
        auto check = [&](const QString &code, int expected) {
            QVERIFY(!engine.evaluate(code).isError());
            QCOMPARE(engine.globalObject().property(u"updates"_s).toInt(), expected);
        };
        check(u"onButtonEvent(0,true)"_s, 1);
        check(u"onButtonEvent(0,false)"_s, 1);
        check(u"mainAction.enabled=false; onButtonEvent(0,true)"_s, 1);
        check(u"mainAction.enabled=true; consoleDrawer.drawerOpen=true; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"consoleEvents"_s).toInt(), 1);
        check(u"globalDrawer.drawerOpen=true; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"drawerEvents"_s).toInt(), 1);
        check(u"root.activeDialog={handleInput:function(){dialogEvents++}}; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"dialogEvents"_s).toInt(), 1);
        check(u"root.activeDialog=null;globalDrawer.drawerOpen=false;consoleDrawer.drawerOpen=false;onButtonEvent(0,true)"_s, 2);
        // Exercise the actual deferred modal release function, including a
        // replacement dialog opening before the deferred callback executes.
        const auto release = handler(u"/components/AppDialog.qml"_s, u"releaseInput"_s);
        QVERIFY(!release.isEmpty());
        QVERIFY(!engine.evaluate(release).isError());
        QVERIFY(!engine.evaluate(u"var deferred=null;var Qt={callLater:function(f){deferred=f}};var activeDialogParent={activeDialog:root};root.visible=false;releaseInput();"_s).isError());
        QVERIFY(engine.evaluate(u"activeDialogParent.activeDialog===root"_s).toBool());
        engine.evaluate(u"deferred();"_s);
        QVERIFY(engine.evaluate(u"activeDialogParent.activeDialog===null"_s).toBool());
        engine.evaluate(u"activeDialogParent.activeDialog=root;releaseInput();var replacement={};activeDialogParent.activeDialog=replacement;deferred();"_s);
        QVERIFY(engine.evaluate(u"activeDialogParent.activeDialog===replacement"_s).toBool());

    }
    void controllerNavigationRespectsModalOwner() {
        QJSEngine engine;
        engine.evaluate(u"var globalDrawer={drawerOpen:false}; var consoleDrawer={drawerOpen:false}; var root={activeDialog:null}; function applicationWindow(){return root;}"_s);
        for (const auto &name : {u"AboutDataOS.qml"_s, u"AboutDataApp.qml"_s, u"rss_feed/RssPage.qml"_s,
                                 u"settings/Settings.qml"_s, u"rebase_helper/RebaseHelper.qml"_s}) {
            QFile file(QStringLiteral(SOURCE_PATH) + u"/pages/"_s + name);
            QVERIFY(file.open(QIODevice::ReadOnly));
            const auto source = QString::fromUtf8(file.readAll());
            const QRegularExpression pattern(u"active:\\s*([^\\n]+(?:\\n\\s*&&[^\\n]+)*)"_s);
            const auto match = pattern.match(source);
            QVERIFY2(match.hasMatch(), qPrintable(name));
            const auto expression = match.captured(1).trimmed();
            engine.evaluate(u"root.activeDialog=null; globalDrawer.drawerOpen=false;"_s);
            const auto normal = engine.evaluate(expression);
            QVERIFY2(!normal.isError() && normal.toBool(), qPrintable(expression));
            engine.evaluate(u"root.activeDialog={};"_s);
            QVERIFY(!engine.evaluate(expression).toBool());
            engine.evaluate(u"root.activeDialog=null; globalDrawer.drawerOpen=true;"_s);
            QVERIFY(!engine.evaluate(expression).toBool());
        }
    }
    void untrustedConfigAndBoundedLogs() {
        QTemporaryDir temp;
        QFile file(temp.filePath(u"fexico-untrusted-test.ini"_s));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.write("[Commands]\nsystemUpdateCommand=/untrusted\n"); file.close();
        const auto previous = qgetenv("XDG_CONFIG_DIRS");
        qputenv("XDG_CONFIG_DIRS", temp.path().toUtf8());
        QVERIFY(findConfigFile(u"fexico-untrusted-test.ini"_s).isEmpty());
        qputenv("XDG_CONFIG_DIRS", previous);
        Console::Model model;
        for (int i = 0; i < 2500; ++i)
            model.newLine(QString(20000, u'x'), Console::LogLevel::Info);
        QVERIFY(model.rowCount() <= 2000);
        QVERIFY(model.data(model.index(0, 0)).toString().size() < 9000);
    }
    void busyAndMissingConfiguration() {
        Console::Model model; QJSEngine engine;
        engine.evaluate(u"var calls=0; function done(c) { if(c!==0) calls++; }"_s);
        auto cb = engine.globalObject().property(u"done"_s);
        appState.setUpdateRunning(true);
        runNativeOperation(&model, command(u"staged"_s), u"rollback"_s, cb);
        QCOMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
        QVERIFY(appState.updateRunning()); QVERIFY(!appState.rollbackRunning());
        appState.setUpdateRunning(false);
        runNativeOperation(&model, {}, u"upgrade"_s, cb);
        QTRY_COMPARE(engine.globalObject().property(u"calls"_s).toInt(), 2);
        QVERIFY(!appState.commandSucceeded()); QVERIFY(!appState.commandRunning());
    }
};
QTEST_MAIN(NativeUpdaterTest)
#include "test_native_updater.moc"
