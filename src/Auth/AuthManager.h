#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtNetwork/QNetworkAccessManager>

class QNetworkReply;

/// @brief Authenticates users against the Node.js / Express backend REST API endpoint.
///
/// Register a single instance as QML context property "authManager" on the QML
/// engine before loading AppRoot.qml. Call login() from QML and listen to
/// loginResult().
class AuthManager : public QObject
{
    Q_OBJECT

public:
    explicit AuthManager(QObject* parent = nullptr);

    /// Called from QML to initiate authentication.
    /// Sends an asynchronous POST request to the backend.
    /// Emits loginResult(bool success, const QString& message) when completed.
    Q_INVOKABLE void login(const QString& username, const QString& password);

signals:
    /// Emitted when authentication completes.
    ///
    /// @param success true if login was accepted
    /// @param message human-readable result
    ///        ("Login successful" on success, error text on failure)
    void loginResult(bool success, const QString& message);

private:
    /// Handles the finished HTTP reply.
    void _onReplyFinished(QNetworkReply* reply);

    QNetworkAccessManager _nam;
};
