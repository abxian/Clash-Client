import Foundation

/// 注入点：测试里换成假实现，就不必碰 URLProtocol，也不会真发网络请求。
public protocol ShenxianyunHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ShenxianyunHTTPClient {}

/// 一次 HTTP 往返的结果，业务层只关心这三样。
struct RawResponse: Sendable {
    let status: Int
    let body: Data
    let retryAfter: TimeInterval?
}

/// 负责：拼 URL、带鉴权头、**按 api_bases 顺序故障转移**、解析后端的统一响应壳。
///
/// 后端的响应壳有两种写法：多数接口用 `{"ok": bool, "message": str}`，
/// `/api/verify` 历史原因用 `{"success": bool, "message": str}`。两种都要认。
struct APITransport: Sendable {
    let http: ShenxianyunHTTPClient
    /// 后端限流较紧（ticket 12/60s、verify 15/60s、exchange 20/60s），超时给短一点更快失败转移。
    let timeout: TimeInterval
    let platform: String

    init(http: ShenxianyunHTTPClient, timeout: TimeInterval = 15, platform: String = ShenxianyunProfile.platform) {
        self.http = http
        self.timeout = timeout
        self.platform = platform
    }

    // MARK: - 单个地址

    func send(
        base: URL, path: String, method: String = "GET",
        body: [String: Any]? = nil, deviceToken: String? = nil, remainingBudget: TimeInterval? = nil
    ) async throws -> RawResponse {
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw ShenxianyunError.invalidResponse("无法拼接 URL：\(base) + \(path)")
        }
        guard !DevelopmentBootstrap.isolated || DevelopmentBootstrap.permits(url) else {
            throw ShenxianyunError.invalidResponse("isolated test blocked a non-loopback endpoint")
        }
        let budget = min(timeout, remainingBudget ?? timeout)
        var request = URLRequest(url: url, timeoutInterval: budget)
        request.httpMethod = method
        request.setValue("Shenxianyun-Apple/" + ShenxianyunProfile.appVersion,
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let deviceToken {
            request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        }
        if var body = body {
            if deviceToken != nil {
                body["app_name"] = ShenxianyunProfile.appName + " iOS"
                body["app_version"] = ShenxianyunProfile.appVersion
                body["platform"] = platform
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let capturedRequest = request
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { try await http.data(for: capturedRequest) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(0.001, budget) * 1_000_000_000))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
        guard let http = response as? HTTPURLResponse else {
            throw ShenxianyunError.invalidResponse("非 HTTP 响应")
        }
        let rawRetryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
        let retryAfter = rawRetryAfter.flatMap { $0.isFinite && $0 > 0 ? min(3600, $0) : nil }
        return RawResponse(status: http.statusCode, body: data, retryAfter: retryAfter)
    }

    // MARK: - 多地址故障转移

    /// Transport/5xx failures may use another official endpoint and the fixed
    /// sxnn relay. Business denial, rate limits and consumed tickets never retry.
    /// One total deadline includes every route; isolated QA cannot reach relay.
    func sendWithFailover(
        bases: [URL], path: String, method: String = "GET",
        body: [String: Any]? = nil, deviceToken: String? = nil
    ) async throws -> RawResponse {
        guard !bases.isEmpty else {
            throw ShenxianyunError.invalidResponse("没有可用的 API 地址")
        }
        var lastError: Error = URLError(.cannotConnectToHost)
        var lastResponse: RawResponse?
        let started = ProcessInfo.processInfo.systemUptime
        var routes = bases.map { ($0, path, method, body) }
        if let relay = Self.relayRoute(bases: bases, path: path, method: method, body: body) {
            routes.append(relay)
        }
        for (index, route) in routes.enumerated() {
            try Task.checkCancellation()
            let remaining = timeout - (ProcessInfo.processInfo.systemUptime - started)
            guard remaining > 0 else { break }
            // Reserve time for fallback rather than let a dead primary consume
            // the entire request budget. No background frequency increase.
            let slice = max(0.001, remaining / Double(routes.count - index))
            do {
                let response = try await send(base: route.0, path: route.1, method: route.2,
                    body: route.3, deviceToken: deviceToken, remainingBudget: slice)
                if response.status < 500 || response.retryAfter != nil { return response }
                lastResponse = response
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as ShenxianyunError {
                throw error
            } catch {
                lastError = error
            }
        }
        try Task.checkCancellation()
        if let lastResponse { return lastResponse }
        throw ShenxianyunError.allEndpointsFailed(underlying: lastError)
    }

    /// The relay is a fixed tenant/operation allowlist, never an arbitrary URL
    /// proxy. Only compiled official HTTPS hosts qualify; test/custom endpoints
    /// and endpoint discovery do not send credentials to it.
    static func relayRoute(bases: [URL], path: String, method: String,
                           body: [String: Any]?) -> (URL, String, String, [String: Any]?)? {
        guard !DevelopmentBootstrap.isolated,
              bases.contains(where: { $0.scheme == "https" &&
                  ["api.sxnn.de", "sxnn.de"].contains($0.host?.lowercased() ?? "") &&
                  $0.user == nil && $0.password == nil && [nil, 443, 5443].contains($0.port) }) else { return nil }
        var operation: String
        var packet = body ?? [:]
        switch (method, path) {
        case ("POST", "/api/verify"): operation = "verify"
        case ("POST", "/api/import/ticket"): operation = "ticket"
        case ("POST", "/api/import/exchange"): operation = "exchange"
        case ("POST", "/api/v2/client/heartbeat"): operation = "heartbeat"
        case ("POST", "/api/v2/client/offline"): operation = "offline"
        default:
            guard method == "GET", path.hasPrefix("/api/update-state/"),
                  let code = String(path.dropFirst("/api/update-state/".count)).removingPercentEncoding,
                  !code.isEmpty, !code.contains("/") else { return nil }
            operation = "state"
            packet = ["code": code]
        }
        return (URL(string: "https://ll.sxnn.de")!, "/v1/client/sxnn/" + operation, "POST", packet)
    }

    // MARK: - 响应壳

    /// 解出 JSON 字典，并把后端的失败壳翻译成 `ShenxianyunError`。
    ///
    /// 注意 HTTP 200 不代表成功：后端有些分支是 200 + `{"success": false}`。
    func decodeEnvelope(_ response: RawResponse) throws -> [String: Any] {
        if response.status == 429 || (response.status == 503 && response.retryAfter != nil) {
            throw ShenxianyunError.rateLimited(retryAfter: response.retryAfter ?? 60)
        }
        let json = (try? JSONSerialization.jsonObject(with: response.body)) as? [String: Any]
        let message = (json?["message"] as? String) ?? ""

        guard let json else {
            // 后端在少数路径上直接返回纯文本（如 /sub 的 "invalid or expired code"）。
            let text = String(data: response.body, encoding: .utf8) ?? ""
            throw ShenxianyunError.server(
                ShenxianyunServerError(statusCode: response.status, message: text))
        }
        // `ok` 与 `success` 是同一语义的两种历史写法。
        let succeeded = (json["ok"] as? Bool) ?? (json["success"] as? Bool) ?? false
        guard (200..<300).contains(response.status), succeeded else {
            throw ShenxianyunError.server(
                ShenxianyunServerError(statusCode: response.status, message: message, code: json["code"] as? String))
        }
        return json
    }
}
