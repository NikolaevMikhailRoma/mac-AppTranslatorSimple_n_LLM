import Foundation

/// A sentence for the popup instead of an NSError dump.
public enum ErrorMessage {
    public static func text(for error: Error, serverURL: String) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                return "No answer from \(serverURL). Is LM Studio or another server running, with a model loaded?"
            case .badURL, .unsupportedURL:
                return "The server URL in Settings is not valid: \(serverURL)"
            default:
                return urlError.localizedDescription
            }
        }
        return (error as NSError).localizedDescription
    }
}
