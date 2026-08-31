#include "AuthManager.h"

#include <QtCore/QByteArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonValue>
#include <QtCore/QString>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(AuthManagerLog, "API.AuthManager");

// ============================================================================
// Configuration
// ============================================================================

/// Backend authentication REST API endpoint.
static constexpr const char* kLoginUrl = "https://yantraauthservice.onrender.com/api/login";

// ============================================================================
// AuthManager
// ============================================================================

AuthManager::AuthManager(QObject* parent) : QObject(parent) {}

// Login

void AuthManager::login(const QString& username, const QString& password)
{
    qCDebug(AuthManagerLog) << "Starting authentication for username:" << username;

    // Build JSON request payload: { "username": "...", "password": "..." }
    QJsonObject requestObj;
    requestObj[QStringLiteral("username")] = username;
    requestObj[QStringLiteral("password")] = password;

    const QByteArray jsonBody = QJsonDocument(requestObj).toJson(QJsonDocument::Compact);

    // Build HTTP POST request with 30-second timeout
    QNetworkRequest request(QUrl(QString::fromUtf8(kLoginUrl)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QByteArrayLiteral("application/json"));
    request.setTransferTimeout(30000);

    // Send request asynchronously
    QNetworkReply* reply = _nam.post(request, jsonBody);

    // Handle response on finish
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply]() { _onReplyFinished(reply); });
}

// ============================================================================
// Handle Backend REST API Response
// ============================================================================

void AuthManager::_onReplyFinished(QNetworkReply* reply)
{
    reply->deleteLater();

    const QByteArray responseData = reply->readAll();
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    qCDebug(AuthManagerLog) << "Auth HTTP status:" << httpStatus << "Network error:" << reply->error()
                            << "Body:" << responseData;

    // Attempt to parse JSON response payload from backend
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseError);

    if (parseError.error == QJsonParseError::NoError && doc.isObject()) {
        const QJsonObject root = doc.object();
        const bool success = root.value(QStringLiteral("success")).toBool(false);
        const QString message = root.value(QStringLiteral("message")).toString();

        if (success) {
            qCDebug(AuthManagerLog) << "Login SUCCESS:" << message;
            emit loginResult(true, message.isEmpty() ? tr("Login successful") : message);
        } else {
            qCDebug(AuthManagerLog) << "Login REJECTED:" << message;
            emit loginResult(false, message.isEmpty() ? tr("Invalid username or password.") : message);
        }
        return;
    }

    // If no valid JSON was returned and a network error occurred
    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(AuthManagerLog) << "Login network error:" << reply->errorString();
        emit loginResult(false, tr("Network error: %1").arg(reply->errorString()));
        return;
    }

    // Unexpected HTTP status code without JSON error body
    if (httpStatus != 200) {
        qCWarning(AuthManagerLog) << "Login HTTP error status:" << httpStatus;
        emit loginResult(false, tr("Server returned HTTP error %1").arg(httpStatus));
        return;
    }

    // Response was not valid JSON
    qCWarning(AuthManagerLog) << "Login invalid response JSON:" << responseData;
    emit loginResult(false, tr("Invalid server response."));
}
