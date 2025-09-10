// Add alias to maintain compatibility with the renamed method
extension APIManager {
    func sendAIInsights(healthData: APIManagerHealthData, cachedItems: [CacheManager.LoggedItem], prompt: String? = nil) async throws -> [AIInsight] {
        return try await uploadCacheAndGenerateInsights(healthData: healthData, cachedItems: cachedItems, prompt: prompt)
    }
}
