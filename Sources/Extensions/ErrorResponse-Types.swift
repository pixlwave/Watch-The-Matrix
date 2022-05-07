import Matrix

extension ErrorResponse {
    /// The access token is invalid and the user should be logged out.
    var isLoggedOut: Bool { code == "M_UNKNOWN_TOKEN" }
}
