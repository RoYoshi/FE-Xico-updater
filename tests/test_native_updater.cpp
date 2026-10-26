// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtTest>
#include <QJSEngine>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
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
        QVERIFY(appState.allowCommands()); QTest::qWait(30);
        QCOMPARE(engine.globalObject().property(u"calls"_s).toInt(), 1);
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
            "var updateAction={enabled:true}; var updateButton={animateClick:function(){updates++}}; "
            "var consoleDrawer={drawerOpen:false,handleInput:function(){consoleEvents++}}; "
            "var globalDrawer={drawerOpen:false,handleInput:function(){drawerEvents++}}; "
            "var root={activeDialog:null,pageStack:{currentItem:{handleInput:pageHandler}}};"_s).isError());
        auto check = [&](const QString &code, int expected) {
            QVERIFY(!engine.evaluate(code).isError());
            QCOMPARE(engine.globalObject().property(u"updates"_s).toInt(), expected);
        };
        check(u"onButtonEvent(0,true)"_s, 1);
        check(u"onButtonEvent(0,false)"_s, 1);
        check(u"updateAction.enabled=false; onButtonEvent(0,true)"_s, 1);
        check(u"updateAction.enabled=true; consoleDrawer.drawerOpen=true; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"consoleEvents"_s).toInt(), 1);
        check(u"globalDrawer.drawerOpen=true; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"drawerEvents"_s).toInt(), 1);
        check(u"root.activeDialog={handleInput:function(){dialogEvents++}}; onButtonEvent(0,true)"_s, 1);
        QCOMPARE(engine.globalObject().property(u"dialogEvents"_s).toInt(), 1);
        check(u"root.activeDialog=null;globalDrawer.drawerOpen=false;consoleDrawer.drawerOpen=false;onButtonEvent(0,true)"_s, 2);
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
