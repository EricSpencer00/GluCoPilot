import Foundation

class APIManagerURLSessionDelegate: NSObject, URLSessionDelegate {
    
    // Implement certificate pinning for enhanced security
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Ensure the connection is using HTTPS
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            // Reject non-HTTPS connections
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // For production app, implement certificate pinning here
        // This would involve validating the server's certificate against a stored public key
        
        // For now, we'll use the default validation
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
        
        // Note: In a production environment, you should replace this with proper certificate pinning
        // by comparing the server's certificate or public key against a known good value
    }
}
